# This code is based on https://github.com/openai/guided-diffusion
"""
Generate a large batch of image samples from a model and save them as a large
numpy array. This can be used to produce samples for FID evaluation.
"""

import json
import os
from pathlib import Path

import numpy as np
import torch
import tqdm

from convert.joints2bvh import BVH, Animation, joints2bvh
from data_loaders.get_data import DatasetConfig, get_dataset_loader
from data_loaders.humanml.scripts.motion_process import (
    preprocess_motion,
    postprocess_motion,
    extract_features,
    recover_from_ric,
    recover_root_rot_pos,
)
from data_loaders.humanml.utils import paramUtil
from model.cfg_sampler import ClassifierFreeSampleModel
from utils import dist_util
from utils.editing_util import get_keyframes_mask
from utils.fixseed import fixseed
from utils.model_util import create_model_and_diffusion, load_saved_model
from utils.parser_util import CondSyntArgs, custom_synt_args


def parse_args() -> CondSyntArgs:
    args = custom_synt_args()
    fixseed(args.seed)

    # Only humanml dataset and the absolute root representation is supported
    # for conditional synthesis
    assert args.dataset == "humanml" and args.abs_3d
    assert args.keyframe_conditioned

    assert (
        args.num_samples <= args.batch_size
    ), f"Please either increase batch_size({args.batch_size}) or reduce num_samples({args.num_samples})"
    # So why do we need this check? In order to protect GPU from a memory overload in the following line.
    # If your GPU can handle batch size larger then default, you can specify it through --batch_size flag.
    # If it doesn't, and you still want to sample more prompts, run this script with different seeds
    # (specify through the --seed flag)

    # Parse list of texts from args
    if args.text_prompt != "":
        texts = [args.text_prompt]
        args.num_samples = 1
    elif args.input_text != "":
        assert os.path.exists(args.input_text)
        with open(args.input_text, "r") as fr:
            texts = fr.readlines()
        texts = [s.replace("\n", "") for s in texts]
        args.num_samples = len(texts)
    elif args.no_text:
        texts = [""] * args.num_samples
        args.guidance_param = 0.0  # Force unconditioned generation
    else:
        raise ValueError("No text supplied!")
    args.texts = texts

    return args


def build_output_path(args) -> Path:
    checkpoint_name = Path(args.model_path).parent.name
    model_results_path = Path("save/results") / checkpoint_name
    niter = Path(args.model_path).stem.replace("model", "")

    method = ""
    if args.imputate:
        method += "_" + "imputation"

    if args.reconstruction_guidance:
        method += "_" + "recg"

    if args.editable_features != "pos_rot_vel":
        edit_mode = args.edit_mode + "_" + args.editable_features
    else:
        edit_mode = args.edit_mode

    out_name = "condsamples{}_{}_{}_T={}_CI={}_CRG={}_KGP={}_seed{}".format(
        niter,
        method,
        edit_mode,
        args.transition_length,
        args.stop_imputation_at,
        args.stop_recguidance_at,
        args.keyframe_guidance_param,
        args.seed,
    )

    if args.text_prompt != "":
        out_name += "_" + args.text_prompt.replace(" ", "_").replace(".", "")
    elif args.input_text != "":
        out_name += "_" + Path(args.input_text).stem.replace(" ", "_").replace(".", "")

    return model_results_path / out_name


def get_minimal_dataloader(args, max_frames, split="test", num_workers=1):
    conf = DatasetConfig(
        name=args.dataset,
        batch_size=args.batch_size,
        num_frames=max_frames,
        split=split,
        hml_mode="train",  # in train mode, you get both text and motion.
        use_abs3d=args.abs_3d,
        traject_only=args.traj_only,
        use_random_projection=args.use_random_proj,
        random_projection_scale=args.random_proj_scale,
        augment_type="none",
        std_scale_shift=args.std_scale_shift,
        drop_redundant=args.drop_redundant,
        minimal=True,
    )
    data = get_dataset_loader(conf, num_workers=num_workers, shuffle=False)
    return data


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


def infer():
    args = parse_args()

    max_frames = (
        196
        if args.dataset in ["kit", "humanml"]
        else (200 if args.dataset == "trajectories" else 60)
    )

    if args.output_dir:
        out_path = Path(args.output_dir)
    else:
        out_path = build_output_path(args)

    ###########################################################################
    # * Load Minimal Dataset and Model
    ###########################################################################

    # Sampling a single batch from the testset, with exactly args.num_samples
    args.batch_size = args.num_samples
    split = "fixed_subset" if args.use_fixed_subset else "test"

    # returns a DataLoader with the Text2MotionDatasetV2 dataset
    print(f"Loading '{split}' split of '{args.dataset}' dataset ...")
    dataloader = get_minimal_dataloader(args, max_frames, split=split)

    print("Creating model and diffusion ...")
    model, diffusion = create_model_and_diffusion(args, dataloader)

    ###########################################################################
    # * Load Model Checkpoint
    ###########################################################################

    print(f"Loading checkpoints from [{args.model_path}] ...")
    load_saved_model(model, args.model_path)  # , use_avg_model=args.gen_avg_model)
    if args.guidance_param != 1 and args.keyframe_guidance_param != 1:
        raise NotImplementedError(
            "Classifier-free sampling for keyframes not implemented."
        )
    elif args.guidance_param != 1:
        # wrapping model with the classifier-free sampler
        model = ClassifierFreeSampleModel(model)
    model.to(dist_util.dev())
    model.eval()  # disable random masking

    ###########################################################################
    # * Prepare Kwargs for Sampling
    ###########################################################################

    # Load BVH and convert it to hml3d format
    bvh_motion, pre_y, pre_xz, pre_rot = get_abs_data_from_bvh(Path(args.bvh_path))

    # Pad or crop to `max_frames`
    if bvh_motion.shape[0] < max_frames:
        frame = torch.zeros(max_frames, bvh_motion.shape[1])
        frame[: bvh_motion.shape[0]] = bvh_motion
        bvh_motion = frame
        n_frames = max_frames
    elif bvh_motion.shape[0] > max_frames:
        n_frames = bvh_motion.shape[0]
        bvh_motion = bvh_motion[:max_frames]

    # Normalize the motion
    input_motions = dataloader.dataset.t2m_dataset.transform_th(bvh_motion)

    # (max_frames, 263) -> (nsamples, 263, 1, max_frames)
    input_motions = input_motions.repeat(args.num_samples, 1, 1, 1)
    input_motions = input_motions.permute(0, 3, 1, 2)
    input_motions = input_motions.to(dist_util.dev())

    # TODO: Check the other sampling scripts how to initialize the mask.
    #       It seems to be used only when `args.imputate` is True.
    model_kwargs = {
        "y": {
            "lengths": torch.tensor([n_frames] * args.num_samples).to(dist_util.dev()),
            "mask": torch.ones((args.num_samples, 1, 1, max_frames), device=dist_util.dev())
        }
    }

    # TODO: Implement sparse keyframe conditioning
    #       - Get the list of keyframes (and joints) from the input motion
    #       - Generate a custom keyframes mask

    model_kwargs["obs_x0"] = input_motions
    model_kwargs["obs_mask"], obs_joint_mask = get_keyframes_mask(
        data=input_motions,
        lengths=model_kwargs["y"]["lengths"],
        edit_mode=args.edit_mode,
        feature_mode=args.editable_features,
        trans_length=args.transition_length,
        get_joint_mask=True,
        n_keyframes=args.n_keyframes,
    )  # [nsamples, njoints, nfeats, nframes]

    assert max_frames == input_motions.shape[-1]

    # Arguments
    model_kwargs["y"]["text"] = args.texts
    model_kwargs["y"]["diffusion_steps"] = args.diffusion_steps

    # Add inpainting mask according to args
    if args.zero_keyframe_loss:
        # if loss is 0 over keyframes durint training, then must impute keyframes during inference
        model_kwargs["y"]["imputate"] = 1
        model_kwargs["y"]["stop_imputation_at"] = 0
        model_kwargs["y"]["replacement_distribution"] = "conditional"
        model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
        model_kwargs["y"]["inpainting_mask"] = model_kwargs[
            "obs_mask"
        ]  # used to do [nsamples, nframes] --> [nsamples, njoints, nfeats, nframes]
        model_kwargs["y"]["reconstruction_guidance"] = False
    elif args.imputate:
        # if loss was present over keyframes during training, we may use imputation at inference time
        model_kwargs["y"]["imputate"] = 1
        model_kwargs["y"]["stop_imputation_at"] = args.stop_imputation_at
        model_kwargs["y"]["replacement_distribution"] = "conditional"
        model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
        model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
        if args.reconstruction_guidance:
            # if loss was present over keyframes during training, we may use guidance at inference time
            model_kwargs["y"]["reconstruction_guidance"] = args.reconstruction_guidance
            model_kwargs["y"]["reconstruction_weight"] = args.reconstruction_weight
            model_kwargs["y"]["gradient_schedule"] = args.gradient_schedule
            model_kwargs["y"]["stop_recguidance_at"] = args.stop_recguidance_at
    elif args.reconstruction_guidance:
        # if loss was present over keyframes during training, we may use guidance at inference time
        model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
        model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
        model_kwargs["y"]["reconstruction_guidance"] = args.reconstruction_guidance
        model_kwargs["y"]["reconstruction_weight"] = args.reconstruction_weight
        model_kwargs["y"]["gradient_schedule"] = args.gradient_schedule
        model_kwargs["y"]["stop_recguidance_at"] = args.stop_recguidance_at

    # add CFG scale to batch
    if args.guidance_param != 1:
        # text classifier-free guidance
        model_kwargs["y"]["text_scale"] = (
            torch.ones(args.batch_size, device=dist_util.dev()) * args.guidance_param
        )
    if args.keyframe_guidance_param != 1:
        # keyframe classifier-free guidance
        model_kwargs["y"]["keyframe_scale"] = (
            torch.ones(args.batch_size, device=dist_util.dev())
            * args.keyframe_guidance_param
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

    sample_fn = diffusion.p_sample_loop

    for rep_i in tqdm.trange(args.num_repetitions, desc="Sampling Repetitions"):
        sample = sample_fn(
            model,
            (args.batch_size, model.njoints, model.nfeats, max_frames),
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
        if model.data_rep == "hml_vec":
            n_joints = 22 if (sample.shape[1] in [263, 264]) else 21
            sample = sample.cpu().permute(0, 2, 3, 1)
            sample = dataloader.dataset.t2m_dataset.inv_transform(sample).float()
            motion = recover_from_ric(sample, n_joints, abs_3d=args.abs_3d)
            motion = motion.view(-1, *motion.shape[2:]).permute(
                0, 2, 3, 1
            )  # batch_size, n_joints=22, 3, n_frames
        all_samples.append(sample.cpu().numpy())
        all_motions.append(motion.cpu().numpy())
        all_lengths.append(model_kwargs["y"]["lengths"].cpu().numpy())

        if args.unconstrained:
            all_text += ["unconstrained"] * args.num_samples
        else:
            text_key = "text" if "text" in model_kwargs["y"] else "action_text"
            all_text += model_kwargs["y"][text_key]

    ###########################################################################
    # * Post-Processing Inputs
    ###########################################################################

    # Unnormalize observed motions and recover XYZ *positions*
    if model.data_rep == "hml_vec":
        input_motions = input_motions.cpu().permute(0, 2, 3, 1)
        input_motions = dataloader.dataset.t2m_dataset.inv_transform(
            input_motions
        ).float()
        input_motions = recover_from_ric(input_motions, n_joints, abs_3d=args.abs_3d)
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

    ###########################################################################
    # * Save Results
    ###########################################################################

    out_path.mkdir(parents=True, exist_ok=True)

    # Write run arguments to json file an save in out_path
    with (out_path / "edit_args.json").open("w") as fw:
        json.dump(vars(args), fw, indent=4, sort_keys=True)

    npy_path = out_path / "results.npy"
    print(f"saving results file to [{npy_path}]")
    np.save(
        npy_path,
        {
            "sample": all_samples,
            "motion": all_motions,
            "text": all_text,
            "lengths": all_lengths,
            "num_samples": args.num_samples,
            "num_repetitions": args.num_repetitions,
            "observed_motion": all_observed_motions,
            "observed_mask": all_observed_masks,
            "pre_y": pre_y,
            "pre_xz": pre_xz,
            "pre_rot": pre_rot,
        },
    )
    with (out_path / "results.txt").open("w") as fw:
        fw.write("\n".join(all_text))

    with (out_path / "results_len.txt").open("w") as fw:
        fw.write("\n".join([str(l) for l in all_lengths]))

    converter = joints2bvh.Joint2BVHConvertor()

    for i_sample in tqdm.trange(args.num_samples, desc="Saving Input BVHs"):
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

    for i_rep in tqdm.trange(args.num_repetitions, desc="Saving Sample BVHs"):
        for i_sample in range(args.num_samples):
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

    # if args.dataset == "humanml":
    #     plot_conditional_samples(
    #         motion=all_motions,
    #         lengths=all_lengths,
    #         texts=all_text,
    #         observed_motion=all_observed_motions,
    #         observed_mask=all_observed_masks,
    #         num_samples=args.num_samples,
    #         num_repetitions=args.num_repetitions,
    #         out_path=out_path,
    #         edit_mode=args.edit_mode,  # FIXME: only works for selected edit modes
    #         stop_imputation_at=0,
    #     )


if __name__ == "__main__":
    infer()
