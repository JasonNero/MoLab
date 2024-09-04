import json
import os
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
import tqdm

from convert.joints2bvh import BVH, Animation, joints2bvh
from data_loaders.get_data import DatasetConfig, get_dataset_loader
from data_loaders.humanml.scripts.motion_process import (
    extract_features,
    postprocess_motion,
    preprocess_motion,
    recover_from_ric,
    recover_root_rot_pos,
)
from data_loaders.humanml.utils import paramUtil
from model.cfg_sampler import ClassifierFreeSampleModel
from utils import dist_util
from utils.editing_util import get_keyframes_mask
from utils.fixseed import fixseed
from utils.model_util import create_model_and_diffusion, load_saved_model
from utils.parser_util import (
    BaseOptions,
    CondSyntOptions,
    CustomSyntOptions,
    DataOptions,
    DiffusionOptions,
    GenerateOptions,
    ModelOptions,
    SamplingOptions,
    TrainingOptions,
)


@dataclass
class ModelArgs(
    BaseOptions,
    DataOptions,
    ModelOptions,
    DiffusionOptions,
    TrainingOptions,
    SamplingOptions,
):
    """Contains Mostly Model Options:
    - `BaseOptions` (`cuda`, `device`, `seed`)
    - `DataOptions` (Dataset Type and Path, Data Representation, Augmentation, ...)
    - `ModelOptions` (Model Architecture)
    - `DiffusionOptions` (Diffusion Hyperparameters)
    - `TrainingOptions` (Save path, Batchsize, LR, Loss Weights, ...)
    - `SamplingOptions` (Model and Output Path, Samples and Reps, CFG Guidance)
    """

    pass


@dataclass
class InferenceArgs(GenerateOptions, CondSyntOptions, CustomSyntOptions):
    """Contains Mostly Inference Options:
    - `GenerateOptions` (Motion Length, Input Text/Action)
    - `CondSynthOptions` (Edit Mode, Editable Features, Imputate, Reconstruction Guidance)
    """

    pass


@dataclass
class AllArgs(ModelArgs, InferenceArgs):
    """Contains all arguments for the conditional synthesis."""

    pass


def get_abs_data_from_bvh(filepath: Path) -> torch.Tensor:
    """Load a BVH file and convert it to HML3D_abs format."""
    animation = BVH.load(filepath)

    # TODO: Define all assumptions about the input BVH file as `asserts`
    assert animation.positions.shape[1] == 22, "Incorrect number of joints in BVH file"

    # Get global joint positions
    joint_positions = torch.from_numpy(Animation.positions_global(animation))

    # Reorder joints to undo the reordering of Joints2BVHConvertor
    joint_positions = joint_positions[:, joints2bvh.re_order_inv]

    positions, pre_y, pre_xz, pre_rot = preprocess_motion(joint_positions)

    fid_r, fid_l = [8, 11], [7, 10]  # Right/Left foot
    face_joint_indx = [2, 1, 17, 16]  # Face direction, r_hip, l_hip, sdr_r, sdr_l
    foot_threshold = 0.002

    # compute relative (original) HML3D representation
    rel_data = extract_features(
        positions,
        foot_threshold,
        torch.from_numpy(paramUtil.t2m_raw_offsets),
        paramUtil.t2m_kinematic_chain,
        face_joint_indx,
        fid_r,
        fid_l,
    )

    # replace relative with absolute root information
    r_rot_quat, r_pos, rot_ang = recover_root_rot_pos(
        torch.from_numpy(rel_data), return_rot_ang=True
    )
    abs_data = rel_data.copy()
    abs_data[:, 0] = rot_ang
    abs_data[:, [1, 2]] = r_pos[:, [0, 2]]

    return torch.from_numpy(abs_data).float(), pre_y, pre_xz, pre_rot


class MotionInferenceWorker:
    def __init__(self, name: str, model_args: ModelArgs):
        """Initialize the worker and parse arguments without starting the model."""
        self.name = name
        self.model_config = model_args

        self.dataloader = None
        self.model = None
        self.diffusion = None

        self.start()

    def get_output_path(
        self,
        infer_config: InferenceArgs,
    ) -> Path:
        """Get the output path for the results of the inference."""

        checkpoint_name = Path(self.model_config.model_path).parent.name
        model_results_path = Path("save/results") / checkpoint_name
        niter = Path(self.model_config.model_path).stem.replace("model", "")

        method = ""
        if infer_config.imputate:
            method += "_" + "imputation"

        if infer_config.reconstruction_guidance:
            method += "_" + "recg"

        if infer_config.editable_features != "pos_rot_vel":
            edit_mode = infer_config.edit_mode + "_" + infer_config.editable_features
        else:
            edit_mode = infer_config.edit_mode

        out_name = "MoLab{}_{}_{}_T={}_CI={}_CRG={}_KGP={}_seed{}".format(
            niter,
            method,
            edit_mode,
            infer_config.transition_length,
            infer_config.stop_imputation_at,
            infer_config.stop_recguidance_at,
            self.model_config.keyframe_guidance_param,
            self.model_config.seed,
        )

        if infer_config.text_prompt != "":
            out_name += "_" + infer_config.text_prompt.replace(" ", "_").replace(
                ".", ""
            )
        elif infer_config.input_text != "":
            out_name += "_" + Path(infer_config.input_text).stem.replace(
                " ", "_"
            ).replace(".", "")

        return model_results_path / out_name

    def start(self):
        """Start the model and load the checkpoint."""

        # Only humanml dataset and the absolute root representation is supported
        # for conditional synthesis
        assert self.model_config.dataset == "humanml" and self.model_config.abs_3d
        assert self.model_config.keyframe_conditioned
        self.max_frames = 196

        fixseed(self.model_config.seed)

        ###########################################################################
        # * Load Minimal Dataset and Model
        ###########################################################################

        # Sampling a single batch from the testset, with exactly args.num_samples
        self.model_config.batch_size = self.model_config.num_samples
        # split = "fixed_subset" if self.model_config.use_fixed_subset else "test"  # TODO: Not sure what this is for
        split = "test"

        # returns a DataLoader with the Text2MotionDatasetV2 dataset
        print(f"Loading '{split}' split of '{self.model_config.dataset}' dataset ...")

        conf = DatasetConfig(
            name=self.model_config.dataset,
            batch_size=self.model_config.batch_size,
            num_frames=self.max_frames,
            split=split,
            hml_mode="train",  # in train mode, you get both text and motion.
            use_abs3d=self.model_config.abs_3d,
            traject_only=self.model_config.traj_only,
            use_random_projection=self.model_config.use_random_proj,
            random_projection_scale=self.model_config.random_proj_scale,
            augment_type="none",
            std_scale_shift=self.model_config.std_scale_shift,
            drop_redundant=self.model_config.drop_redundant,
            minimal=True,  # Minimal dataset, loads only std/mean for normalization
        )
        self.dataloader = get_dataset_loader(conf, num_workers=1, shuffle=False)

        print("Creating model and diffusion ...")
        self.model, self.diffusion = create_model_and_diffusion(
            self.model_config, self.dataloader
        )

        ###########################################################################
        # * Load Model Checkpoint
        ###########################################################################

        print(f"Loading checkpoints from [{self.model_config.model_path}] ...")
        load_saved_model(self.model, self.model_config.model_path)
        if (
            self.model_config.guidance_param != 1
            and self.model_config.keyframe_guidance_param != 1
        ):
            raise NotImplementedError(
                "Classifier-free sampling for keyframes not implemented."
            )
        elif self.model_config.guidance_param != 1:
            # wrapping model with the classifier-free sampler
            self.model = ClassifierFreeSampleModel(self.model)
        self.model.to(dist_util.dev())
        self.model.eval()  # disable random masking

    def stop(self):
        self.dataloader = None
        self.model = None
        self.diffusion = None

    def restart(self):
        self.stop()
        self.start()

    def infer(self, infer_config: InferenceArgs, save_results: bool = True):
        """Infer using model args and save results to output directory.

        Args:
            save_results (bool, optional): Whether to save outputs to disk. Defaults to True.

        Returns:
            dict: Dictionary containing the following results of the inference:
                * sample: Samples generated by the model.
                * motion: Rotational motion derived from the samples.
                * text: Text prompts used for each sample.
                * lengths: Lengths of the generated samples/motions.
                * num_samples: Number of samples generated.
                * num_repetitions: Number of repetitions.
                * observed_motion: Input motion used for sampling.
                * observed_mask: Mask used for inpainting.
                * pre_y: Preprocessing parameters for root Y-axis.
                * pre_xz: Preprocessing parameters for root XZ-plane.
                * pre_rot: Preprocessing parameters for root rotation.
        """
        ###########################################################################
        # * Prepare Text and Motion Inputs for Sampling
        ###########################################################################

        if infer_config.text_prompt != "":
            # Single text prompt -> Single sample
            texts = [infer_config.text_prompt]
            self.model_config.num_samples = 1

        elif infer_config.input_text != "":
            # Load text prompts from file -> Variable sample count
            assert os.path.exists(infer_config.input_text)
            with open(infer_config.input_text, "r") as fr:
                texts = fr.readlines()
            texts = [s.replace("\n", "") for s in texts]
            self.model_config.num_samples = len(texts)

        elif infer_config.no_text:
            # No text -> Keep sample count
            texts = [""] * self.model_config.num_samples
            infer_config.guidance_param = 0.0  # Force unconditioned generation

        else:
            raise ValueError("No text supplied!")

        # Load BVH and convert it to hml3d format
        bvh_motion, pre_y, pre_xz, pre_rot = get_abs_data_from_bvh(
            Path(infer_config.bvh_path)
        )

        # Pad or crop to `max_frames`
        if bvh_motion.shape[0] < self.max_frames:
            frame = torch.zeros(self.max_frames, bvh_motion.shape[1])
            frame[: bvh_motion.shape[0]] = bvh_motion
            bvh_motion = frame
            n_frames = self.max_frames
        elif bvh_motion.shape[0] > self.max_frames:
            n_frames = bvh_motion.shape[0]
            bvh_motion = bvh_motion[: self.max_frames]

        # Normalize the motion
        input_motions = self.dataloader.dataset.t2m_dataset.transform_th(bvh_motion)

        # (max_frames, 263) -> (nsamples, 263, 1, max_frames)
        input_motions = input_motions.repeat(self.model_config.num_samples, 1, 1, 1)
        input_motions = input_motions.permute(0, 3, 1, 2)
        input_motions = input_motions.to(dist_util.dev())

        # TODO: Check the other sampling scripts how to initialize the mask.
        #       It seems to be used only when `args.imputate` is True.
        model_kwargs = {
            "y": {
                "lengths": torch.tensor([n_frames] * self.model_config.num_samples).to(
                    dist_util.dev()
                ),
                "mask": torch.ones(
                    (self.model_config.num_samples, 1, 1, self.max_frames),
                    device=dist_util.dev(),
                ),
            }
        }

        # TODO: Implement sparse keyframe conditioning
        #       - Get the list of keyframes (and joints) from the input motion
        #       - Generate a custom keyframes mask

        model_kwargs["obs_x0"] = input_motions
        model_kwargs["obs_mask"], obs_joint_mask = get_keyframes_mask(
            data=input_motions,
            lengths=model_kwargs["y"]["lengths"],
            edit_mode=infer_config.edit_mode,
            feature_mode=infer_config.editable_features,
            trans_length=infer_config.transition_length,
            get_joint_mask=True,
            n_keyframes=infer_config.n_keyframes,
        )  # [nsamples, njoints, nfeats, nframes]

        assert self.max_frames == input_motions.shape[-1]

        # Arguments
        model_kwargs["y"]["text"] = texts
        model_kwargs["y"]["diffusion_steps"] = self.model_config.diffusion_steps

        # Add inpainting mask according to args
        if self.model_config.zero_keyframe_loss:
            # if loss is 0 over keyframes during training, then force imputation at inference time
            model_kwargs["y"]["imputate"] = 1
            model_kwargs["y"]["stop_imputation_at"] = 0
            model_kwargs["y"]["replacement_distribution"] = "conditional"
            model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
            model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
            model_kwargs["y"]["reconstruction_guidance"] = False

        elif infer_config.imputate:
            # if loss was present over keyframes during training, we may use imputation at inference time
            model_kwargs["y"]["imputate"] = 1
            model_kwargs["y"]["stop_imputation_at"] = infer_config.stop_imputation_at
            model_kwargs["y"]["replacement_distribution"] = "conditional"
            model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
            model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
            if infer_config.reconstruction_guidance:
                # if loss was present over keyframes during training, we may use guidance at inference time
                model_kwargs["y"]["reconstruction_guidance"] = (
                    infer_config.reconstruction_guidance
                )
                model_kwargs["y"]["reconstruction_weight"] = (
                    infer_config.reconstruction_weight
                )
                model_kwargs["y"]["gradient_schedule"] = infer_config.gradient_schedule
                model_kwargs["y"]["stop_recguidance_at"] = (
                    infer_config.stop_recguidance_at
                )

        elif infer_config.reconstruction_guidance:
            # if loss was present over keyframes during training, we may use guidance at inference time
            model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
            model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
            model_kwargs["y"]["reconstruction_guidance"] = (
                infer_config.reconstruction_guidance
            )
            model_kwargs["y"]["reconstruction_weight"] = (
                infer_config.reconstruction_weight
            )
            model_kwargs["y"]["gradient_schedule"] = infer_config.gradient_schedule
            model_kwargs["y"]["stop_recguidance_at"] = infer_config.stop_recguidance_at

        # Add CFG scale to batch
        if self.model_config.guidance_param != 1:
            # text classifier-free guidance
            model_kwargs["y"]["text_scale"] = (
                torch.ones(self.model_config.batch_size, device=dist_util.dev())
                * self.model_config.guidance_param
            )
        if self.model_config.keyframe_guidance_param != 1:
            # keyframe classifier-free guidance
            model_kwargs["y"]["keyframe_scale"] = (
                torch.ones(self.model_config.batch_size, device=dist_util.dev())
                * self.model_config.keyframe_guidance_param
            )

        all_samples = []
        all_motions = []
        all_lengths = []
        all_text = []
        all_observed_motions = []
        all_observed_masks = []

        ###########################################################################
        # * Sampling
        ###########################################################################

        # TODO: Kinda convoluted to use two variables for the same thing, unify them.
        assert self.model_config.num_samples == self.model_config.batch_size

        for _ in tqdm.trange(
            self.model_config.num_repetitions, desc="Sampling Repetitions"
        ):
            sample = self.diffusion.p_sample_loop(
                self.model,
                (
                    self.model_config.batch_size,
                    self.model.njoints,
                    self.model.nfeats,
                    self.max_frames,
                ),
                clip_denoised=False,
                model_kwargs=model_kwargs,
                skip_timesteps=0,  # 0 is the default value - i.e. don't skip any step
                init_image=None,
                progress=True,
                dump_steps=None,
                noise=None,
                const_noise=False,
            )  # [nsamples, njoints, nfeats, nframes]

            ###########################################################################
            # * Post-Processing Samples
            ###########################################################################

            # Unnormalize samples and recover XYZ *positions*
            if self.model.data_rep == "hml_vec":
                n_joints = 22 if (sample.shape[1] in [263, 264]) else 21
                sample = sample.cpu().permute(0, 2, 3, 1)
                sample = self.dataloader.dataset.t2m_dataset.inv_transform(
                    sample
                ).float()
                motion = recover_from_ric(
                    sample, n_joints, abs_3d=self.model_config.abs_3d
                )
                # Reshape to (batch_size, n_joints=22, 3, n_frames)
                motion = motion.view(-1, *motion.shape[2:]).permute(0, 2, 3, 1)
            all_samples.append(sample.cpu().numpy())
            all_motions.append(motion.cpu().numpy())
            all_lengths.append(model_kwargs["y"]["lengths"].cpu().numpy())

            all_text += model_kwargs["y"]["text"]

        ###########################################################################
        # * Post-Processing Inputs
        ###########################################################################

        # Unnormalize observed motions and recover XYZ *positions*
        if self.model.data_rep == "hml_vec":
            input_motions = input_motions.cpu().permute(0, 2, 3, 1)
            input_motions = self.dataloader.dataset.t2m_dataset.inv_transform(
                input_motions
            ).float()
            input_motions = recover_from_ric(
                input_motions, n_joints, abs_3d=self.model_config.abs_3d
            )
            input_motions = input_motions.view(-1, *input_motions.shape[2:]).permute(
                0, 2, 3, 1
            )
            input_motions = input_motions.cpu().numpy()
            inpainting_mask = obs_joint_mask.cpu().numpy()

        all_samples = np.stack(all_samples)
        all_motions = np.stack(all_motions)  # [num_rep, num_samples, 22, 3, n_frames]
        all_text = np.stack(all_text)  # [num_rep, num_samples]
        all_lengths = np.stack(all_lengths)  # [num_rep, num_samples]
        all_observed_motions = input_motions  # [num_samples, 22, 3, n_frames]
        all_observed_masks = inpainting_mask

        results_dict = {
            "sample": all_samples,
            "motion": all_motions,
            "text": all_text,
            "lengths": all_lengths,
            "num_samples": self.model_config.num_samples,
            "num_repetitions": self.model_config.num_repetitions,
            "observed_motion": all_observed_motions,
            "observed_mask": all_observed_masks,
            "pre_y": pre_y,
            "pre_xz": pre_xz,
            "pre_rot": pre_rot,
        }

        if save_results:
            out_path = self.get_output_path(infer_config)
            out_path.mkdir(parents=True, exist_ok=True)

            # Write run arguments to json file an save in out_path
            with (out_path / "infer_args.json").open("w") as fw:
                json.dump(vars(infer_config), fw, indent=4, sort_keys=True)

            npy_path = out_path / "results.npy"
            print(f"saving results file to [{npy_path}]")
            np.save(npy_path, results_dict)

            # with (out_path / "results.txt").open("w") as fw:
            #     fw.write("\n".join(all_text))
            # with (out_path / "results_len.txt").open("w") as fw:
            #     fw.write("\n".join([str(l) for l in all_lengths]))

            converter = joints2bvh.Joint2BVHConvertor()

            for i_sample in tqdm.trange(
                self.model_config.num_samples, desc="Saving Input BVHs"
            ):
                # Input Motion
                length = all_lengths[0, i_sample]
                motion = all_observed_motions[i_sample, :, :, :length]  # Crop
                motion = motion.transpose(2, 0, 1)  # Put frames first

                motion = postprocess_motion(motion, pre_y, pre_xz, pre_rot)

                save_path = out_path / f"sample{i_sample:02d}_input.bvh"
                converter.convert(
                    motion,
                    save_path,
                    iterations=10,
                    foot_ik=False,
                )

            for i_rep in tqdm.trange(
                self.model_config.num_repetitions, desc="Saving Sample BVHs"
            ):
                for i_sample in range(self.model_config.num_samples):
                    length = all_lengths[i_rep, i_sample]
                    motion = all_motions[i_rep, i_sample, :, :, :length]  # Crop
                    motion = motion.transpose(2, 0, 1)  # Put frames first

                    motion = postprocess_motion(motion, pre_y, pre_xz, pre_rot)

                    save_path = out_path / f"sample{i_sample:02d}_rep{i_rep:02d}.bvh"
                    converter.convert(
                        motion,
                        save_path,
                        iterations=10,
                        foot_ik=False,
                    )

        return results_dict
