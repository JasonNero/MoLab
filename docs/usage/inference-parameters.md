# Inference Parameters

## Overview

The most common inference arguments are:

- `text_prompt`: The description of the desired motion.
- `num_samples`: The number of samples to generate.
- `packed_motion` The input motion to be used as a starting point for the inference.

Instead of `packed_motion`, you can also infer from a local BVH file using:

- `bvh_file`: The path to the local BVH file to be used as input motion.
- `edit_mode` The masking mode applied onto the input motion.

Further options that might be interesting to adjust are:

- `unpack_mode`: How to unpack the motion and fill the missing values, can be stepped or linearly interpolated.
- `unpack_randomness`: The randomness applied during unpacking.
- `editable_features`: The features (joint positions, rotations and velocities) that are extracted from the input motion.

For an extended list of available parameters see the API Reference, specifically the [InferenceArgs][models.condmdi.molab_condmdi.inference_worker.InferenceArgs] class.
