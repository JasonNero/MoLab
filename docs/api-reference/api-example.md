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

> [!EXAMPLE]
> Below is an example of a `packed_motion` dictionary with one keypose
> on frame `0` and some missing joint rotations.
> 
> ```python
> {
>   "0": [                                    
>     [0.006335, 0.925889, 0.022782],         
>     [-1.848952, 5.855419, -2.209308],       
>     [-2.225391, 0.251401, 2.091639],
>     [-1.218372, -0.323186, 12.9199],
>     [7.476767, 15.311409, 1.712001],
>     [NaN, NaN, NaN],                        
>     [-2.184482, 1.651783, -23.240063],
>     [-2.814711, 1.391872, 20.864488],
>     [4.163708, 2.049498, 16.159805],
>     [NaN, NaN, NaN],
>     [3.729861, -0.337432, 4.422964],
>     [2.408384, -1.4252, 3.27613],
>     [-9.129623, -1.656823, 3.135745],
>     [13.112406, -5.187206, -21.793815],
>     [NaN, NaN, NaN],
>     [-11.362097, -26.660376, 10.556817],
>     [-51.782502, -43.877115, 14.017005],
>     [132.977088, -62.445882, -104.782485],
>     [NaN, NaN, NaN],
>     [10.967079, 12.768552, 5.388521],
>     [67.233545, 46.770885, 23.864491],
>     [-125.065474, 57.771444, -84.861314],
>     [NaN, NaN, NaN],
>   ],
> }
> ```

For details on how to pack keyframes, see the [`pack_keyframes`][dcc.molab_maya.motion_io.pack_keyframes] function of the Maya integration below.
It takes a list of positions and a list of rotations that can contain `NaN` values and converts them to a `packed_motion` dictionary.

::: dcc.molab_maya.motion_io.pack_keyframes
    options:
      heading_level: 3
      show_root_heading: true

## Send Job to Backend

Now that we have the `packed_motion` dictionary, we can craft our inference arguments and send them to the backend.
Below is the documentation for [`MoLabClient.infer`][dcc.molab_maya.client.MoLabClient.infer], which does the following:

- Take a dictionary inference arguments (see [`InferenceArgs`][models.condmdi.molab_condmdi.inference_worker.InferenceArgs])
- Connect to the backend via WebSocket
- Send the job and wait for the result
- Return the result dictionary (see [`InferenceResults`][models.condmdi.molab_condmdi.inference_worker.InferenceResults])

::: dcc.molab_maya.client.MoLabClient.infer
    options:
      heading_level: 3
      show_root_heading: true

## Apply Output Motion

The [`InferenceResults`][models.condmdi.molab_condmdi.inference_worker.InferenceResults] contains `root_positions` and `joint_rotations` fields of shape `(S, F, 3)` and `(S, F, 22, 3)` respectively, where `S` is the sample count, `F` is the number of frames.

For debugging purposes the results also contain the input motion as `obs_root_positions` and `obs_joint_rotations`.

In the [`apply_motion`][dcc.molab_maya.motion_io.apply_motion] function below, we show how to apply the output motion to a character rig in Maya.

::: dcc.molab_maya.motion_io.apply_motion
    options:
      heading_level: 3
      show_root_heading: true
