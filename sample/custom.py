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

from data_loaders.get_data import DatasetConfig, get_dataset_loader
from data_loaders.humanml.scripts.motion_process import recover_from_ric
from data_loaders.humanml.utils.plotting import plot_conditional_samples
from data_loaders.tensors import collate
from model.cfg_sampler import ClassifierFreeSampleModel
from utils import dist_util
from utils.editing_util import get_keyframes_mask
from utils.fixseed import fixseed
from utils.model_util import create_model_and_diffusion, load_saved_model
from utils.parser_util import CondSyntArgs, cond_synt_args


def parse_args() -> CondSyntArgs:
    args = cond_synt_args()
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

    return args


def get_texts(args) -> list:
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
        # use text from the test set
        texts = []
    return texts


def build_output_path(args) -> Path:
    checkpoint_name = Path(args.model_path).stem
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


def infer():
    args = parse_args()

    max_frames = (
        196
        if args.dataset in ["kit", "humanml"]
        else (200 if args.dataset == "trajectories" else 60)
    )
    fps = 12.5 if args.dataset == "kit" else 20
    n_frames = min(max_frames, int(args.motion_length * fps))

    if args.output_dir:
        out_path = Path(args.output_dir)
    else:
        out_path = build_output_path(args)

    texts = get_texts(args)

    ###########################################################################
    # * Load Dataset and Model
    # TODO: Remove the need for a full local dataset.
    #       Only supply mean/std somehow.
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
    # TODO: Build a custom `y` aka `model_kwargs` from user input
    #       (see synthesize.py for an example)
    ###########################################################################

    # this is basically `x, y = next(dataset)`
    # input_motions, model_kwargs = next(iter(data))

    # TODO: add `text` and the corresponding `tokens` to collate args
    collate_args = [
        {"inp": torch.zeros(n_frames), "tokens": None, "lengths": n_frames}
    ] * args.num_samples
    collate_args = [dict(arg, text=txt) for arg, txt in zip(collate_args, texts)]
    input_motions, model_kwargs = collate(collate_args)

    # TODO: This is still missing custom input_motions from user input
    #       - Load BVH and convert it to hml3d format
    #           - This should give `input_motions`
    #       - Build my own keyframe mask (`obs_mask`)

    print(f"Putting input motions on device '{dist_util.dev()}' ...")
    input_motions = input_motions.to(
        dist_util.dev()
    )  # [nsamples, njoints=263/1, nfeats=1/3, nframes=196/200]
    input_masks = model_kwargs["y"]["mask"]  # [nsamples, 1, 1, nframes]
    input_lengths = model_kwargs["y"]["lengths"]  # [nsamples]

    model_kwargs["obs_x0"] = input_motions
    model_kwargs["obs_mask"], obs_joint_mask = get_keyframes_mask(
        data=input_motions,
        lengths=input_lengths,
        edit_mode=args.edit_mode,
        feature_mode=args.editable_features,
        trans_length=args.transition_length,
        get_joint_mask=True,
        n_keyframes=args.n_keyframes,
    )  # [nsamples, njoints, nfeats, nframes]

    assert max_frames == input_motions.shape[-1]

    # Arguments
    model_kwargs["y"]["text"] = texts
    model_kwargs["y"]["diffusion_steps"] = args.diffusion_steps

    # Add inpainting mask according to args
    if args.zero_keyframe_loss:  # if loss is 0 over keyframes durint training, then must impute keyframes during inference
        model_kwargs["y"]["imputate"] = 1
        model_kwargs["y"]["stop_imputation_at"] = 0
        model_kwargs["y"]["replacement_distribution"] = "conditional"
        model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
        model_kwargs["y"]["inpainting_mask"] = model_kwargs[
            "obs_mask"
        ]  # used to do [nsamples, nframes] --> [nsamples, njoints, nfeats, nframes]
        model_kwargs["y"]["reconstruction_guidance"] = False
    elif args.imputate:  # if loss was present over keyframes during training, we may use imputation at inference time
        model_kwargs["y"]["imputate"] = 1
        model_kwargs["y"]["stop_imputation_at"] = args.stop_imputation_at
        model_kwargs["y"]["replacement_distribution"] = "conditional"
        model_kwargs["y"]["inpainted_motion"] = model_kwargs["obs_x0"]
        model_kwargs["y"]["inpainting_mask"] = model_kwargs["obs_mask"]
        if args.reconstruction_guidance:  # if loss was present over keyframes during training, we may use guidance at inference time
            model_kwargs["y"]["reconstruction_guidance"] = args.reconstruction_guidance
            model_kwargs["y"]["reconstruction_weight"] = args.reconstruction_weight
            model_kwargs["y"]["gradient_schedule"] = args.gradient_schedule
            model_kwargs["y"]["stop_recguidance_at"] = args.stop_recguidance_at
    elif args.reconstruction_guidance:  # if loss was present over keyframes during training, we may use guidance at inference time
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

    all_motions = []
    all_lengths = []
    all_text = []
    all_observed_motions = []
    all_observed_masks = []

    ###########################################################################
    # * Sampling
    ###########################################################################

    sample_fn = diffusion.p_sample_loop

    for rep_i in range(args.num_repetitions):
        print(f"### Start sampling [repetition #{rep_i}/{args.num_repetitions}]")

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

        # Unnormalize samples and recover XYZ *positions*
        if model.data_rep == "hml_vec":
            n_joints = 22 if (sample.shape[1] in [263, 264]) else 21
            sample = sample.cpu().permute(0, 2, 3, 1)
            sample = dataloader.dataset.t2m_dataset.inv_transform(sample).float()
            sample = recover_from_ric(sample, n_joints, abs_3d=args.abs_3d)
            sample = sample.view(-1, *sample.shape[2:]).permute(
                0, 2, 3, 1
            )  # batch_size, n_joints=22, 3, n_frames

        all_motions.append(sample.cpu().numpy())
        all_lengths.append(model_kwargs["y"]["lengths"].cpu().numpy())

        if args.unconstrained:
            all_text += ["unconstrained"] * args.num_samples
        else:
            text_key = "text" if "text" in model_kwargs["y"] else "action_text"
            all_text += model_kwargs["y"][text_key]

        print(f"created {len(all_motions) * args.batch_size} samples")
        # Sampling is done!

    ###########################################################################
    # * Post-Processing (observed motions here; sample above)
    ###########################################################################

    # Unnormalize observed motions and recover XYZ *positions*
    if model.data_rep == "hml_vec":
        input_motions = input_motions.cpu().permute(0, 2, 3, 1)
        input_motions = dataloader.dataset.t2m_dataset.inv_transform(input_motions).float()
        input_motions = recover_from_ric(input_motions, n_joints, abs_3d=args.abs_3d)
        input_motions = input_motions.view(-1, *input_motions.shape[2:]).permute(
            0, 2, 3, 1
        )
        input_motions = input_motions.cpu().numpy()
        inpainting_mask = obs_joint_mask.cpu().numpy()

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
            "motion": all_motions,
            "text": all_text,
            "lengths": all_lengths,
            "num_samples": args.num_samples,
            "num_repetitions": args.num_repetitions,
            "observed_motion": all_observed_motions,
            "observed_mask": all_observed_masks,
        },
    )
    with (out_path / "results.txt").open("w") as fw:
        fw.write(
            "\n".join(all_text)
        )  # TODO: Fix this for datasets other thah trajectories

    with (out_path / "results_len.txt").open("w") as fw:
        fw.write("\n".join([str(l) for l in all_lengths]))

    if args.dataset == "humanml":
        plot_conditional_samples(
            motion=all_motions,
            lengths=all_lengths,
            texts=all_text,
            observed_motion=all_observed_motions,
            observed_mask=all_observed_masks,
            num_samples=args.num_samples,
            num_repetitions=args.num_repetitions,
            out_path=out_path,
            edit_mode=args.edit_mode,  # FIXME: only works for selected edit modes
            stop_imputation_at=0,
        )


if __name__ == "__main__":
    infer()
