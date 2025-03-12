"""MoLab Client to compare inference parameters combinations.

# Usage:
1. Select Hip Bone of the source skeleton
2. Adapt the `test_grids` below
3. Run the script
"""

import itertools
from pprint import pprint

from molab_maya import motion_io
from molab_maya.qclient import MoLabQClient

# Global tracking variables
client = MoLabQClient("ws://localhost:8000")
current_inference = 0
total_inferences = 0
waiting_for_result = False
grid_keys = []
parameter_combinations = []
skeleton_group = None
packed_motion = None


def on_inference_finished(result):
    global waiting_for_result

    print(
        f"Inference {current_inference}/{total_inferences} finished. Importing the results..."
    )
    motion_io.import_motions(
        skeleton_group,
        result["root_positions"],
        result["joint_rotations"],
        start_frame=0,
        name=f"sample{current_inference}",
    )

    # Mark this inference as complete
    waiting_for_result = False

    # Move to the next inference or close if done
    process_next_inference()


def process_next_inference():
    global current_inference, waiting_for_result

    # Check if we've processed all inferences
    if current_inference >= total_inferences:
        print("All inferences completed. Closing client...")
        client.close()
        return

    # Get the next set of parameters
    params = parameter_combinations[current_inference]
    data = dict(zip(grid_keys, params))
    if packed_motion and "packed_motion" in data:
        data["packed_motion"] = packed_motion

    print(
        f"\n========== Starting Inference [{current_inference + 1}/{total_inferences}] =========="
    )
    pprint(data, depth=2)
    print("================================================")

    # Send the inference request
    client.infer(data)

    # Mark that we're waiting for this inference to complete
    waiting_for_result = True
    current_inference += 1
    print("Waiting for inference result...")


def infer_by_grid_search(grid: dict[str, list], insert_packed_motion=None):
    """Takes a dictionary of lists. Each list is a parameter to search over.
    The search/test space is the cartesian product of all the lists.
    """
    global total_inferences, parameter_combinations, grid_keys, packed_motion

    grid_keys = list(grid.keys())
    packed_motion = insert_packed_motion

    # Generate all parameter combinations
    parameter_combinations = list(itertools.product(*grid.values()))
    total_inferences = len(parameter_combinations)

    print(f"Running sequential inference on {total_inferences} parameter combinations.")
    print(f"This will take approx. {total_inferences * 2} minutes on Apple M3.")

    # Start the first inference
    process_next_inference()


try:
    # Initialize the client globally
    client.open()
    current_inference = 0
    waiting_for_result = False

    # Extracting the keyframes for the skeleton under the selected hip bone
    joints = motion_io.get_selected_skeleton_joints()
    skeleton_group = joints[0].getParent()
    packed_motion = motion_io.extract_and_pack_keyframes(joints)

    # Usage with packed_motion
    packed_motion_test_grid = {
        "packed_motion": [None],
        "num_samples": [1],
        "foot_ik": [False],
        "jacobian_ik": [False],
        "editable_features": ["pos_rot_vel", "pos_rot", "pos"],
        "unpack_mode": ["linear"],
        "unpack_randomness": [0.0],
    }

    client.inference_received.connect(on_inference_finished)
    client.connected.connect(
        lambda: infer_by_grid_search(packed_motion_test_grid, packed_motion)
    )

    # Client will be closed when all inferences complete

except Exception as e:
    print(f"An error occurred: {e}")
    if client:
        client.close()
    print("Client closed due to an error.")
