# API Usage Example

As example on how to use the API for inference, we'll first take a look at the `dcc.molab_maya.client` module to see how to connect to the backend and send a job for inference.

Then we will look at some methods in `dcc.molab_maya.motion_io` to see how to handle input and output motions.

> [!TIP]
> A Blender integration is an open issue and a good opportunity for a contribution!

## Collect Input Motion

To be able to pass motion data around, we need to understand the motion format at input and output. The input format `packed_motion` is a bit special due to its sparse nature, while the output format is more straightforward.

Part of the [`InferenceArgs`][models.condmdi.molab_condmdi.inference_worker.InferenceArgs] is the `packed_motion` field. This is a dictionary mapping frame indices to packed poses, where a packed pose contains the root position followed by all 22 joint rotations, so it has a shape of `(23, 3)`.
Values stored as `NaN` indicate sparse keyframes aka missing joint information.
The `NaN` values are later converted to a joint mask for the inference model.

For details on how to pack keyframes, see the [`pack_keyframes`][dcc.molab_maya.motion_io.pack_keyframes] function of the Maya integration below.
It takes a list of positions and a list of rotations that can contain `NaN` values and converts them to a `packed_motion` dictionary.

::: dcc.molab_maya.motion_io.pack_keyframes
    options:
      heading_level: 3
      show_root_heading: true

## Send Job to Backend

Now that we have the `packed_motion` dictionary, we can craft our inference arguments and send them to the backend.
Below is the documentation for [`MoLabQClient.infer`][dcc.molab_maya.qclient.MoLabQClient.infer], which does the following:

- Take a dictionary inference arguments (see [`InferenceArgs`][models.condmdi.molab_condmdi.inference_worker.InferenceArgs])
- Connect to the backend via WebSocket
- Send the job and wait for the result
- Return the result dictionary (see [`InferenceResults`][models.condmdi.molab_condmdi.inference_worker.InferenceResults])

> [!EXAMPLE]
>
> Below is a full payload example for the `MoLabQClient.infer` method containing two keyposes on frame 0 and 42 as well as a text prompt.
>
> ```json
> {
>     "packed_motion": {
>         0: [
>             [0.0, 0.966035, 0.0],
>             [-2.461784, 1.602837, 3.02837205],
>             [-1.15376, -0.314741, -3.40727],
>             [1.123194, -0.57072, 9.6684651],
>             [5.430555, 12.008284, 3.450807],
>             [nan, nan, nan],
>             [0.699208, 0.478575, -4.624878],
>             [-0.736858, 0.472722, 8.868751],
>             [1.046311, 0.36474, 4.513838],
>             [nan, nan, nan],
>             [-2.097379, 0.002352, 1.437366],
>             [6.395149, -0.91336201, -23.965065],
>             [0.203726, -2.443971, 29.728936],
>             [0.572847, 0.573686, -19.469958],
>             [nan, nan, nan],
>             [-13.751465, 5.598898, -3.18948],
>             [-67.052628, -7.37833, -6.440387],
>             [-23.210149, -25.2472202, 7.097196],
>             [nan, nan, nan],
>             [7.634399, -1.97200502, -1.282972],
>             [69.428653, 6.069861, -6.181875],
>             [10.862561, 27.296937, 3.88993195],
>             [nan, nan, nan],
>         ],
>         42: [
>             [-0.339078, 0.965653, 2.350223],
>             [-2.312009, 2.433177, -1.82445502],
>             [3.73811, -1.674805, -25.165169],
>             [-8.567456, 1.59987202, 19.844779],
>             [17.532981, 30.0588684, 19.2560214],
>             [nan, nan, nan],
>             [-0.172514997, -1.10521, 10.58829],
>             [1.696808, -0.023274, 7.59669],
>             [-2.601748, -8.717805, 7.61317205],
>             [nan, nan, nan],
>             [-1.07286802, -0.173289, 5.375921],
>             [4.720364, -0.666077, -21.613376],
>             [5.729873, 8.757588, 32.877729],
>             [-4.825603, 6.19364, -15.489852],
>             [nan, nan, nan],
>             [-12.313785, 3.51262305, -3.91042395],
>             [-60.028995, -1.354013, -10.010531],
>             [-21.320532, -21.962499, 4.864524],
>             [nan, nan, nan],
>             [1.25623, 5.556887, 2.128571],
>             [49.840547, 17.558537, 0.472948984],
>             [1.83383397, 29.8473266, 2.299576],
>             [nan, nan, nan],
>         ],
>     },
>     "text_prompt": "A person walks forward",
>     "num_samples": 3,
>     "type": "infer",
> }
> ```

::: dcc.molab_maya.qclient.MoLabQClient.infer
    options:
      heading_level: 3
      show_root_heading: true

## Apply Output Motion

The [`InferenceResults`][models.condmdi.molab_condmdi.inference_worker.InferenceResults] contains `root_positions` and `joint_rotations` fields of shape `(S, F, 3)` and `(S, F, 22, 3)` respectively, where `S` is the sample count, `F` is the number of frames.

For debugging purposes the results also contain the input motion as `obs_root_positions` and `obs_joint_rotations`.

In the [`_apply_motion`][dcc.molab_maya.motion_io._apply_motion] function below, we show how to apply the output motion to a character rig in Maya.

::: dcc.molab_maya.motion_io._apply_motion
    options:
      heading_level: 3
      show_root_heading: true
