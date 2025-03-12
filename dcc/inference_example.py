"""Simple MoLab Client

# Usage:
1. Select Hip Bone of the source skeleton
2. Adapt the `inference_args` below
3. Run the script
"""

from molab_maya import motion_io
from molab_maya.qclient import MoLabQClient

# Initialize the client
client = MoLabQClient("ws://localhost:8000")

def on_inference_finished(result, skeleton_group):
    print("Inference finished. Importing the results ...")
    motion_io.import_motions(
        skeleton_group,
        result["root_positions"],
        result["joint_rotations"],
        start_frame=0,
        name="sample",
    )
    client.close()

def start_inference():
    # Extracting the keyframes for the skeleton under the selected hip bone
    joints = motion_io.get_selected_skeleton_joints()
    skeleton_group = joints[0].getParent()
    packed_motion = motion_io.extract_and_pack_keyframes(joints)

    # Preparing the inference arguments
    inference_args = {
        "packed_motion": packed_motion,
        "text_prompt": "A person walks forward",
        "num_samples": 3,
    }
    # Sending the inference request and importing the results separately
    client.inference_received.connect(lambda result: on_inference_finished(result, skeleton_group))
    client.infer(inference_args)
    print("Inference request sent. Waiting for results ...")

try:
    client.open()
    client.connected.connect(start_inference)
except Exception as e:
    print(f"An error occurred: {e}")
    if client:
        client.close()
    print("Client closed due to an error.")
