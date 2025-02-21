import json
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd
import torch
import tqdm
from pydantic import BaseModel

from .convert.joints2bvh import BVH, Animation, joints2bvh
from .convert.joints2bvh.Quaternions import Quaternions
from .data_loaders.get_data import DatasetConfig, get_dataset_loader
from .data_loaders.humanml.scripts.motion_process import (
    extract_features,
    postprocess_motion,
    preprocess_motion,
    recover_from_ric,
    recover_root_rot_pos,
)
from .data_loaders.humanml.utils import paramUtil
from .model.cfg_sampler import ClassifierFreeSampleModel
from .utils import dist_util
from .utils.editing_util import get_keyframes_mask, joint_to_full_mask
from .utils.fixseed import fixseed
from .utils.model_util import create_model_and_diffusion, load_saved_model
from .utils.parser_util import (
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
    - `CustomSyntOptions` (BVH Path)
    """

    # A mapping of frame indices to poses (J+1, 3) where J is the number of joints.
    # The first index is the root position, followed by all joint rotations.
    # Uses `nan` to indicate missing values / sparse keyframes.
    packed_motion: dict[int, list] = field(default_factory=dict)
    num_samples: int = field(default=3)  # Override the model `num_samples`
    jacobian_ik: bool = field(default=False)
    foot_ik: bool = field(default=False)
    unpack_randomness: float = 0.0
    unpack_mode: str = field(
        default="linear",
        metadata={
            "choices": [
                "step",
                "linear"
            ],
        },
    )


class InferenceResults(BaseModel):
    """Contains Inference Results. Uses Pydantic for serialization."""

    # motions: list  # Technically: list[np.ndarray]
    root_positions: list
    joint_rotations: list

    obs_root_positions: list
    obs_joint_rotations: list


def get_jointpos_from_bvh(filepath: Path) -> torch.Tensor:
    """Load a BVH file and convert it to HML3D_abs format."""
    assert Path(filepath).is_file(), f"BVH file not found: {filepath}"

    animation = BVH.load(filepath)

    # TODO: Define all assumptions about the input BVH file as `asserts`
    assert animation.positions.shape[1] == 22, "Incorrect number of joints in BVH file"

    # Get global joint positions
    joint_positions = Animation.positions_global(animation)

    # Reorder joints to undo the reordering of Joints2BVHConvertor
    joint_positions = joint_positions[:, joints2bvh.re_order_inv]

    return joint_positions


def unpack_motion(
    packed_motion: dict[int, list],
    mode: str = "linear",
    randomness: float = 0.00,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Unpack the packed motion input and return the joint positions and mask.

    Packed Motion Format:
    - A dictionary mapping frame indices to packed poses
    - A packed pose contains the root position followed by all 22 joint rotations
    - Values stored as `nan` indicate sparse keyframes and are converted to a joint mask

    Args:
        packed_motion (dict[int, list]): Packed motion data
        mode (str, optional): Interpolation mode, either "linear" or "step".
            Defaults to "linear".
        randomness (float, optional): Random noise to add to the missing values.
            Defaults to 0.0.

    Returns:
        np.ndarray: Root positions (n_frames, 3)
        np.ndarray: Joint rotations (n_frames, 22, 3)
        np.ndarray: Joint mask (n_frames, 22, 1)
    """
    packed_motion = {int(k): np.array(v) for k, v in packed_motion.items()}

    # We actually have 22 joints, but are piggybacking the root pos in the first index.
    assert next(iter(packed_motion.values())).shape[0] == 23, "Expected 22 joints + 1"

    n_input_frames = np.max(list(packed_motion.keys())) + 1

    # NOTE: Alternatives for handling sparse/masked data: `np.ma` or `scipy.sparse`
    motion = np.ones((n_input_frames, 22 + 1, 3)) * np.nan
    joint_mask = np.zeros((n_input_frames, 22 + 1, 1), dtype=bool)
    for frame, pose in packed_motion.items():
        _pose_mask = ~np.isnan(pose)
        motion[frame, _pose_mask] = pose[_pose_mask]
        joint_mask[frame] = _pose_mask.all(axis=-1).reshape(-1, 1)

    nan_mask = np.isnan(motion)

    if mode == "linear":
        # Use Linear interpolate to fill between known values
        # Fill the rest with zeros to handle border values and joints without data
        df_x = pd.DataFrame(motion[..., 0]).interpolate(method='linear', axis=0).fillna(0)
        df_y = pd.DataFrame(motion[..., 1]).interpolate(method='linear', axis=0).fillna(0)
        df_z = pd.DataFrame(motion[..., 2]).interpolate(method='linear', axis=0).fillna(0)
        motion[..., 0] = df_x.values
        motion[..., 1] = df_y.values
        motion[..., 2] = df_z.values
    elif mode == "step":
        # Fill forwards (basically stepped animation)
        # Fill backwards to get rid of left-border values
        # Fill the rest with zeros to handle joints without data
        # NOTE: This results in jumpy velocities, not ideal for In-Betweening
        df_x = pd.DataFrame(motion[..., 0]).ffill().bfill().fillna(0)
        df_y = pd.DataFrame(motion[..., 1]).ffill().bfill().fillna(0)
        df_z = pd.DataFrame(motion[..., 2]).ffill().bfill().fillna(0)
        motion[..., 0] = df_x.values
        motion[..., 1] = df_y.values
        motion[..., 2] = df_z.values

    if randomness > 0.0:
        # Add random noise to the nan values
        pos_noise = np.random.normal(0, randomness, (n_input_frames, 3))
        rot_noise = np.random.normal(0, randomness, (n_input_frames, 22, 3)) * 180  # degrees
        motion[:, 0][nan_mask[:, 0]] += pos_noise[nan_mask[:, 0]]
        motion[:, 1:][nan_mask[:, 1:]] += rot_noise[nan_mask[:, 1:]]

    if np.isnan(motion).sum() > 0:
        raise ValueError("Unfilled nan values in the input motion.")

    # Extract root position and mask
    root_pos = motion[:, 0].copy()
    root_mask = joint_mask[:, 0].copy()
    rotations = motion[:, 1:]
    joint_mask = joint_mask[:, 1:]

    # Theoretically, this should always hold true, otherwise we would
    # need separate joint and feature masks (which is possible).
    assert np.all(
        np.equal(root_mask, joint_mask[:, 0])
    ), "Root pos mask does not match root rot mask"

    return root_pos, rotations, joint_mask


def unpacked_motion_to_jointpos(
    root_pos: np.ndarray,
    rotations: np.ndarray,
) -> torch.Tensor:
    """Convert the unpacked motion to joint positions using the BVH template and
    Forward Kinematics.

    This is based on the following list of assumptions:
    - The skeleton is the same as in `template.bvh` (22 joints)
        - This is used to get `parents`, `offsets` and `names`
    - Frametime is 1/20s (as per HML3D dataset)
    - Rotation order is XYZ
    """

    # HACK: Hardcoded for now
    # TODO: Why? Why is this needed when Maya says it's xyz?!
    ORDER = "zyx"
    input_frames = rotations.shape[0]

    # Using the BVH template to get offsets, orients, parents and names
    template_path = Path(BVH.__file__).parent / "data" / "template.bvh"
    template_anim = BVH.load(template_path, need_quater=True)

    # NOTE: `positions` and `rotations` are both local to the parent joint
    anim = template_anim.copy()
    anim.frametime = 1.0 / 20.0
    anim.rotations = Quaternions.from_euler(np.radians(rotations), order=ORDER)
    anim.positions = anim.offsets[np.newaxis].repeat(input_frames, axis=0)
    anim.positions[:, 0] = root_pos

    joint_positions = Animation.positions_global(anim)

    # TODO: Assure the original BVH ordering in the Maya/Blender Export
    #       Also investigate the reason for this whole (re)ordering,
    #       do we really need hardcoded indices here?

    # Reorder joints to undo the reordering of Joints2BVHConvertor
    joint_positions = joint_positions[:, joints2bvh.re_order_inv]

    return joint_positions


def get_abs_data_from_jointpos(joint_positions: np.ndarray) -> torch.Tensor:
    """Convert joint positions to HML3D_abs format."""
    positions, pre_y, pre_xz, pre_rot = preprocess_motion(joint_positions)

    fid_r, fid_l = [8, 11], [7, 10]  # Right/Left foot
    face_joint_indx = [2, 1, 17, 16]  # Face direction, r_hip, l_hip, sdr_r, sdr_l
    foot_threshold = 0.002

    # TODO: This loses one frame due to the derivative calculation (aka velocity).
    #       But we could just repeat/emulate the velocity of the last frame,
    #       then we get to keep the positional & rotational information.
    #       This change might have implications for the model though.

    # compute relative (original) HML3D representation
    rel_data = extract_features(
        positions.copy(),  # ensure no in-place modification of positions
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

    # Override the relative root position with the known absolute root position.
    # The calculated `r_pos` seems to have an increasing error over time.
    # TODO: Also evaluate replacing `rot_ang` with the known root rotation.
    abs_data = rel_data.copy()
    abs_data[:, [1, 2]] = positions[:-1, 0, [0, 2]]
    abs_data[:, 0] = rot_ang

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

        split = "test"
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

        if dist_util.dev().type == "mps":
            # NOTE: Compiled Inference Time on M3:
            #       - "inductor" not supported
            #       - "aot_eager" slows down inference by 20%
            pass
        elif (
            dist_util.dev().type == "cuda"
            and torch.cuda.get_device_capability()[0] >= 7
        ):
            self.model.model.compile(backend="inductor")

    def stop(self):
        self.dataloader = None
        self.model = None
        self.diffusion = None

    def restart(self):
        self.stop()
        self.start()

    def infer(
        self, infer_config: InferenceArgs, save_results: bool = True
    ) -> InferenceResults:
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

        # Handle Text Input
        # TODO: Put all this text handling into validator?
        if infer_config.text_prompt != "":
            texts = [infer_config.text_prompt] * infer_config.num_samples
        elif infer_config.input_text != "":
            # ! Variable sample count
            assert Path(infer_config.input_text).is_file()
            with Path(infer_config.input_text).open("r") as fr:
                texts = fr.readlines()
            texts = [s.replace("\n", "") for s in texts]
            print(
                f"Loaded [{len(texts)}] text prompts from [{infer_config.input_text}]"
            )
            infer_config.num_samples = len(texts)
        elif infer_config.no_text:
            texts = [""] * infer_config.num_samples
            infer_config.guidance_param = 0.0  # Force unconditioned generation
        else:
            print("No text provided, implicitly setting `no_text=True`.")
            infer_config.no_text = True
            texts = [""] * infer_config.num_samples
            infer_config.guidance_param = 0.0  # Force unconditioned generation

        input_joint_mask = None
        input_motion_preprocessed = None

        # Handle Motion Input
        if infer_config.bvh_path != "":
            # Load BVH and convert it to hml3d format
            input_motion_preprocessed, pre_y, pre_xz, pre_rot = get_abs_data_from_jointpos(
                get_jointpos_from_bvh(Path(infer_config.bvh_path))
            )
        elif infer_config.packed_motion:
            # Unpack sparse keyframes and convert them to hml3d format
            _root_pos, _rotations, input_joint_mask = unpack_motion(
                infer_config.packed_motion,
                mode=infer_config.unpack_mode,
                randomness=infer_config.unpack_randomness,
            )
            keyframe_pos = unpacked_motion_to_jointpos(_root_pos, _rotations)
            input_motion_preprocessed, pre_y, pre_xz, pre_rot = get_abs_data_from_jointpos(
                keyframe_pos
            )

        if input_motion_preprocessed is not None:
            # Normalize the motion
            input_motion_normalized = self.dataloader.dataset.t2m_dataset.transform_th(
                input_motion_preprocessed
            )

            # Pad or crop to `max_frames`
            if input_motion_normalized.shape[0] < self.max_frames:
                frame = torch.zeros(self.max_frames, input_motion_normalized.shape[1])
                frame[: input_motion_normalized.shape[0]] = input_motion_normalized
                frame[input_motion_normalized.shape[0] :] = input_motion_normalized[-1]  # Repeat last frame
                input_motion_normalized = frame
                n_frames = input_motion_normalized.shape[0]
            elif input_motion_normalized.shape[0] >= self.max_frames:
                n_frames = self.max_frames
                input_motion_normalized = input_motion_normalized[: self.max_frames]
        else:
            print("No motion provided, using zero motion as input.")
            # TODO: Allow supplying a custom length
            n_frames = self.max_frames
            input_motion_normalized = torch.zeros(n_frames, 263)
            input_joint_mask = np.zeros((n_frames, 22, 1))
            pre_y = pre_xz = pre_rot = None

        # (max_frames, 263) -> (nsamples, 263, 1, max_frames)
        input_motions = input_motion_normalized.repeat(infer_config.num_samples, 1, 1, 1)
        input_motions = input_motions.permute(0, 3, 1, 2)
        input_motions = input_motions.to(dist_util.dev())

        # TODO: Check the other sampling scripts how to initialize the mask.
        #       It seems to be used only when `args.imputate` is True.
        model_kwargs = {
            "y": {
                "lengths": torch.tensor([n_frames] * infer_config.num_samples).to(
                    dist_util.dev()
                ),
                "mask": torch.ones(
                    (infer_config.num_samples, 1, 1, self.max_frames),
                    device=dist_util.dev(),
                ),
            }
        }

        # Convert/generate feature mask
        obs_feature_mask = None
        if input_joint_mask is not None:
            # input_joint_mask: (n_inputframes, 22, 1)
            # obs_joint_mask:   (nsamples, 22, 1, max_frames)
            # obs_feature_mask: (nsamples, 263, 1, max_frames)

            obs_joint_mask = torch.zeros(
                (infer_config.num_samples, 22, 1, self.max_frames),
                dtype=bool,
                device=dist_util.dev(),
            )

            n_inframes = min(input_joint_mask.shape[0], self.max_frames)  # crop if needed

            obs_joint_mask[..., :n_inframes] = torch.from_numpy(
                input_joint_mask[None, :n_frames]
                .repeat(infer_config.num_samples, axis=0)
                .transpose(0, 2, 3, 1)
            )

            # TODO: Test the `editable_features` parameter
            obs_feature_mask = joint_to_full_mask(
                obs_joint_mask, mode=infer_config.editable_features
            )
        else:
            print(f"Using mode {infer_config.edit_mode} to get masks.")
            obs_feature_mask, obs_joint_mask = get_keyframes_mask(
                data=input_motions,
                lengths=model_kwargs["y"]["lengths"],
                edit_mode=infer_config.edit_mode,
                feature_mode=infer_config.editable_features,
                trans_length=infer_config.transition_length,
                get_joint_mask=True,
                n_keyframes=infer_config.n_keyframes,
            )  # [nsamples, njoints, nfeats, nframes]

        # TODO: Check whether this is really necessary or I'm just paranoid ...
        # input_motions *= obs_feature_mask

        if input_motions is not None:
            model_kwargs["obs_x0"] = input_motions
            model_kwargs["obs_mask"] = obs_feature_mask

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
                model_kwargs["y"][
                    "reconstruction_guidance"
                ] = infer_config.reconstruction_guidance
                model_kwargs["y"][
                    "reconstruction_weight"
                ] = infer_config.reconstruction_weight
                model_kwargs["y"]["gradient_schedule"] = infer_config.gradient_schedule
                model_kwargs["y"][
                    "stop_recguidance_at"
                ] = infer_config.stop_recguidance_at

        elif infer_config.reconstruction_guidance:
            # if loss was present over keyframes during training, we may use guidance at inference time
            model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
            model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
            model_kwargs["y"][
                "reconstruction_guidance"
            ] = infer_config.reconstruction_guidance
            model_kwargs["y"][
                "reconstruction_weight"
            ] = infer_config.reconstruction_weight
            model_kwargs["y"]["gradient_schedule"] = infer_config.gradient_schedule
            model_kwargs["y"]["stop_recguidance_at"] = infer_config.stop_recguidance_at

        # Add CFG scale to batch
        if self.model_config.guidance_param != 1:
            # text classifier-free guidance
            model_kwargs["y"]["text_scale"] = (
                torch.ones(infer_config.num_samples, device=dist_util.dev())
                * self.model_config.guidance_param
            )
        if self.model_config.keyframe_guidance_param != 1:
            # keyframe classifier-free guidance
            model_kwargs["y"]["keyframe_scale"] = (
                torch.ones(infer_config.num_samples, device=dist_util.dev())
                * self.model_config.keyframe_guidance_param
            )

        all_samples = []
        all_motions_pos = []
        all_lengths = []
        all_text = []
        all_observed_motions_pos = []
        all_observed_masks = []

        ###########################################################################
        # * Sampling
        ###########################################################################

        # If no text is provided, we can bypass the Classifier Free Guidance
        # and half the inference time.
        if infer_config.no_text:
            print("Sampling without text guidance ...")
            model_to_sample = self.model.model
        else:
            model_to_sample = self.model

        for _ in tqdm.trange(
            self.model_config.num_repetitions, desc="Sampling Repetitions"
        ):
            sample = self.diffusion.p_sample_loop(
                model_to_sample,
                (
                    infer_config.num_samples,
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
                motion_pos = recover_from_ric(
                    sample, n_joints, abs_3d=self.model_config.abs_3d
                )
                # Reshape to (batch_size, n_joints=22, 3, n_frames)
                motion_pos = motion_pos.view(-1, *motion_pos.shape[2:])

            all_samples.append(sample.cpu().numpy())
            all_motions_pos.append(motion_pos.cpu().numpy())
            all_lengths.append(model_kwargs["y"]["lengths"].cpu().numpy())

            all_text += model_kwargs["y"]["text"]

        ###########################################################################
        # * Post-Processing Inputs and Save/Return Results
        ###########################################################################

        # Unnormalize observed motions and recover XYZ *positions*
        if self.model.data_rep == "hml_vec":
            input_motions = input_motions.cpu().permute(0, 2, 3, 1)
            input_motions = self.dataloader.dataset.t2m_dataset.inv_transform(
                input_motions
            ).float()
            input_motions_pos = recover_from_ric(
                input_motions, n_joints, abs_3d=self.model_config.abs_3d
            )
            input_motions_pos = input_motions_pos.view(-1, *input_motions_pos.shape[2:])
            input_motions_pos = input_motions_pos.cpu().numpy()
            inpainting_mask = obs_joint_mask.permute(0, 3, 1, 2).cpu().numpy()

        all_samples = np.stack(all_samples)
        all_motions_pos = np.stack(
            all_motions_pos
        )  # [num_rep, num_samples, n_frames, 22, 3]
        all_text = np.stack(all_text)  # [num_rep, num_samples]
        all_lengths = np.stack(all_lengths)  # [num_rep, num_samples]
        all_observed_motions_pos = input_motions_pos  # [n_frames, num_samples, 22, 3]
        all_observed_masks = inpainting_mask

        out_path = self.get_output_path(infer_config)
        out_path.mkdir(parents=True, exist_ok=True)

        # Write run arguments to json file an save in out_path
        with (out_path / "infer_args.json").open("w") as fw:
            json.dump(vars(infer_config), fw, indent=4, sort_keys=True)

        converter = joints2bvh.Joint2BVHConvertor()

        all_postpro_obs_motions_pos = []
        all_postpro_obs_motions_rot = []

        for i_sample in tqdm.trange(infer_config.num_samples, desc="Saving Input BVHs"):
            # Input Motion
            length = all_lengths[0, i_sample]
            motion = all_observed_motions_pos[i_sample, :, :, :length]  # Crop
            motion = postprocess_motion(motion, pre_y, pre_xz, pre_rot)
            all_postpro_obs_motions_pos.append(motion)

            if save_results:
                save_path = out_path / f"sample{i_sample:02d}_input.bvh"
            else:
                save_path = None
            new_anim, _ = converter.convert(
                motion,
                save_path,
                iterations=10,
                foot_ik=infer_config.foot_ik,
                use_jacobian=infer_config.jacobian_ik,
            )
            all_postpro_obs_motions_rot.append(
                np.rad2deg(new_anim.rotations.euler(order="xyz"))
            )

        all_postpro_motions_pos = []
        all_postpro_motions_rot = []

        for i_rep in tqdm.trange(
            self.model_config.num_repetitions, desc="Saving Sample BVHs"
        ):
            for i_sample in range(infer_config.num_samples):
                length = all_lengths[i_rep, i_sample]
                motion = all_motions_pos[i_rep, i_sample, :, :, :length]  # Crop
                motion = postprocess_motion(motion, pre_y, pre_xz, pre_rot)
                all_postpro_motions_pos.append(motion)
                if save_results:
                    save_path = out_path / f"sample{i_sample:02d}_rep{i_rep:02d}.bvh"
                else:
                    save_path = None

                new_anim, _ = converter.convert(
                    motion,
                    save_path,
                    iterations=10,
                    foot_ik=infer_config.foot_ik,
                    use_jacobian=infer_config.jacobian_ik,
                )
                all_postpro_motions_rot.append(
                    np.rad2deg(new_anim.rotations.euler(order="zyx"[::-1])) # see BVH.py:245
                )

        if save_results:
            # TODO: Clean that up at some point, or output only in debug mode.
            results_dict = {
                "sample": all_samples,
                "motion": all_motions_pos,
                "postprocessed_motion": all_postpro_motions_pos,
                "text": all_text,
                "lengths": all_lengths,
                "num_samples": infer_config.num_samples,
                "num_repetitions": self.model_config.num_repetitions,
                "observed_motion": all_observed_motions_pos,
                "observed_mask": all_observed_masks,
                "pre_y": pre_y,
                "pre_xz": pre_xz,
                "pre_rot": pre_rot,
            }
            npy_path = out_path / "results.npy"
            print(f"saving results file to [{npy_path}]")
            np.save(npy_path, results_dict)

        return InferenceResults(
            root_positions=[m[:, 0, :].tolist() for m in all_postpro_motions_pos],
            joint_rotations=[m.tolist() for m in all_postpro_motions_rot],
            obs_root_positions=[m[:, 0, :].tolist() for m in all_postpro_obs_motions_pos],
            obs_joint_rotations=[m.tolist() for m in all_postpro_obs_motions_rot],
        )


def _test():
    # model_path = Path(__file__).parent / "save" / "condmdi_random_joints" / "model000750000.pt"
    model_path = Path(__file__).parent / "save" / "condmdi_random_frames" / "model000750000.pt"

    assert model_path.is_file(), f"Model checkpoint not found at [{model_path}]"

    model_args_path = model_path.parent / "args.json"
    with model_args_path.open("r") as file:
        model_dict = json.load(file)

    # Filter out only the model arguments (ignores `EvaluationOptions`)
    model_args = ModelArgs(
        **{k: v for k, v in model_dict.items() if k in ModelArgs.__dataclass_fields__}
    )
    model_args.model_path = model_path
    model_args.num_repetitions = 1
    model_args.num_samples = 1

    worker = MotionInferenceWorker("worker", model_args)

    infer_dict: dict = {
        # "bvh_path": "sample/dummy.bvh",
        # "text_prompt": "Worker walks into a bar",
        "num_samples": 1,
        "packed_motion": {
            "0": [
                [0.006335, 0.925889, 0.022782],
                [-1.848952, 5.855419, -2.209308],
                [-2.225391, 0.251401, 2.091639],
                [-1.218372, -0.323186, 12.9199],
                [7.476767, 15.311409000000001, 1.712001],
                [0.0, 0.0, 0.0],
                [-2.184482, 1.651783, -23.240063],
                [-2.814711, 1.391872, 20.864488],
                [4.163708, 2.049498, 16.159805],
                [0.0, 0.0, 0.0],
                [3.729861, -0.337432, 4.422964],
                [2.408384, -1.4252, 3.27613],
                [-9.129623, -1.656823, 3.135745],
                [13.112406, -5.187206, -21.793815],
                [0.0, 0.0, 0.0],
                [-11.362097, -26.660376, 10.556817],
                [-51.782502, -43.877115, 14.017005],
                [132.977088, -62.445882, -104.782485],
                [0.0, 0.0, 0.0],
                [10.967079, 12.768552, 5.388521],
                [67.233545, 46.770885, 23.864491],
                [-125.065474, 57.771444, -84.861314],
                [0.0, 0.0, 0.0],
            ],
            "3": [
                [-0.005397, 0.923839, 0.038262],
                [-2.944292, 11.688877, -0.744433],
                [1.330347, -0.54384, -6.42566],
                [-2.461061, -1.037096, 25.45655],
                [5.155187, 11.443451, 3.14162],
                [0.0, 0.0, 0.0],
                [-1.958387, 1.366517, -22.168222],
                [-0.577779, 0.385054, 18.883832],
                [0.015543, -3.8655960000000005, 14.135998],
                [0.0, 0.0, 0.0],
                [3.4149730000000003, -0.55504, 6.905263],
                [1.382484, -0.791695, 1.400716],
                [-7.933509000000001, 3.7116560000000005, 2.637238],
                [15.413932000000003, -4.118027, -28.096708],
                [0.0, 0.0, 0.0],
                [-9.153748, -27.823949000000002, 9.350787],
                [-43.505833, -49.495025, 12.898866],
                [64.612952, -57.545172, -38.580461],
                [0.0, 0.0, 0.0],
                [10.838178, 14.427333, 7.570341],
                [45.742547, 54.182692, 18.629589],
                [-70.799916, 42.813622, -24.305144],
                [0.0, 0.0, 0.0],
            ],
            "4": [
                [-0.001765, 0.925816, 0.054307],
                [-3.725732, 12.670698, -2.237916],
                [4.608602, -0.474464, -6.318524],
                [-5.343978, -0.430467, 28.755527000000004],
                [12.128289, 23.607741, 10.015787],
                [0.0, 0.0, 0.0],
                [-0.879221, 1.500142, -21.414124],
                [-1.14147, 0.476827, 21.571616],
                [-0.540815, -5.032799, 15.559959],
                [0.0, 0.0, 0.0],
                [3.697301, -0.667363, 8.050449],
                [0.529855, -0.299849, 0.591786],
                [-7.173179000000001, 6.867548, 3.730258],
                [16.663089000000003, -4.834545, -26.58799],
                [0.0, 0.0, 0.0],
                [-8.517065, -28.319879000000004, 8.938752],
                [-31.162397000000002, -46.34815, 7.183754999999999],
                [52.002, -53.22641500000001, -28.400572000000004],
                [0.0, 0.0, 0.0],
                [9.081599, 16.898637, 8.935075],
                [28.47988, 50.958105, 9.339571],
                [-62.39294000000001, 46.62553, -22.598966],
                [0.0, 0.0, 0.0],
            ],
            "9": [
                [0.008035, 0.880018, 0.034304],
                [-2.27324, 24.479031, -4.485215],
                [7.304753, -0.781987, -10.104969],
                [-8.509794, -2.191417, 41.200228],
                [5.749923, 6.93057, -8.615016],
                [0.0, 0.0, 0.0],
                [-9.876022, -2.184774, -28.880068999999995],
                [5.098005, -6.16919, 43.525683],
                [-4.680638, -11.334446, 6.293945],
                [0.0, 0.0, 0.0],
                [3.232715, -0.610529, 7.64939],
                [-6.456206, 2.968811, -1.032531],
                [-3.360464, 18.495897, 5.631643],
                [23.504173, -9.795774, -19.990481],
                [0.0, 0.0, 0.0],
                [-5.656359, -8.609517, -0.31699600000000006],
                [-9.048457, -35.650475, -0.76012],
                [99.236589, -30.058303000000002, -45.053273],
                [0.0, 0.0, 0.0],
                [-5.406511, 13.903595, 4.479021],
                [9.39165, 15.831369999999998, -0.41817],
                [-14.650218000000002, 10.990762, -0.079215],
                [0.0, 0.0, 0.0],
            ],
            "10": [
                [0.004019, 0.872268, 0.025836],
                [-1.755083, 27.3451, -2.633481],
                [7.145027000000001, -1.07325, -13.17809],
                [-7.836206, -3.479632, 44.087649],
                [5.176777, 0.49769599999999997, -14.886387000000001],
                [0.0, 0.0, 0.0],
                [-10.852122, -3.225971, -31.103845],
                [5.80187, -7.921004000000001, 46.706103],
                [-6.359201, -14.977151000000001, 2.76627],
                [0.0, 0.0, 0.0],
                [3.435323, -0.5459680000000001, 6.583863],
                [-9.047144, 3.9601350000000006, -2.3822130000000006],
                [-2.988933, 18.627451000000004, 5.638191],
                [22.962958, -9.383703, -19.590579],
                [0.0, 0.0, 0.0],
                [-8.58717, -5.944162, -2.686332],
                [-3.7354569999999994, -35.300409, -2.001034],
                [102.827854, -21.3613, -35.058615],
                [0.0, 0.0, 0.0],
                [-3.672455, 9.356965, 3.259471],
                [12.307579, 7.272943, -1.152276],
                [-10.127301000000001, 9.465788, 0.134461],
                [0.0, 0.0, 0.0],
            ],
        },
    }
    result = worker.infer(InferenceArgs(**infer_dict))

    worker.stop()

if __name__ == "__main__":
    _test()
