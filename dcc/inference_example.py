"""Simple MoLab Client

NOTE: Freezes Maya for the duration of the `recv` call.

# Usage:
1. Select Hip Bone of the source skeleton
2. Adapt the `inference_args` below
3. Run the script and wait for Maya to un-freeze
"""

from molab_maya import motion_io
from molab_maya.client import MoLabClient

# Initialize the client
client = MoLabClient("ws://localhost:8000")

# Extracting the keyframes for the skeleton under the selected hip bone
packed_motion = motion_io.extract_and_pack_keyframes()

# Preparing the inference arguments
inference_args = {
    "packed_motion": packed_motion,
    "text_prompt": "A person walks forward",
    "num_samples": 3,
}

# Sending the inference request and directly importing the results
client.infer_and_import(inference_args, start_frame=0, name="sample")

