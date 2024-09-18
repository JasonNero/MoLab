"""Simple blocking client using `websockets`.

NOTE: Freezes Maya for the duration of the `recv` call.
"""

import itertools
import json
import sys
from pprint import pprint
from importlib import reload
import time

try:
    from websockets.sync.client import connect
except ImportError as e:
    print("Please install the `websockets` package for the DCC python!")
    raise e

# TODO: Remove this
sys.path.append("/Users/jason/repos/diffusion-motion-inbetweening")

if sys.modules.get("maya"):
    from dcc.maya import motion_io
elif sys.modules.get("bpy"):
    from dcc.blender import motion_io
reload(motion_io)


def infer(data):
    with connect("ws://localhost:8000/infer", max_size=2**21) as websocket:
        print(f"Sending:\n{data}")
        websocket.send(json.dumps(data))
        print("Waiting for response...")

        message = websocket.recv()
        result = json.loads(message)
        print(f"Received:\n{result}")

    return result


def infer_by_grid_search(grid: dict[str, list], packed_motion=None):
    """Takes a dictionary of lists. Each list is a parameter to search over.
    The search/test space is the cartesian product of all the lists.
    """

    product = list(itertools.product(*grid.values()))
    print(f"Running inference on {len(product)} parameter combinations.")
    print(f"This will take approx. {len(product) * 2} minutes on Apple M3.")
    time.sleep(2)  # Give Maya some time to print

    for i, params in enumerate(product):
        data = dict(zip(grid.keys(), params))
        if packed_motion and "packed_motion" in data:
            data["packed_motion"] = packed_motion

        print(f"\n========== Infer by Grid Search [{i+1}/{len(product)}] ==========")
        pprint(data, depth=2)
        print("================================================")

        result = infer(data)

        motion_io.import_motions(
            result["root_positions"],
            result["joint_rotations"],
            start_frame=0,
            name=f"gs{i}_sample",
        )

        motion_io.import_motions(
            result["obs_root_positions"][:1],
            result["obs_joint_rotations"][:1],
            start_frame=0,
            name=f"gs{i}_obs",
        )



###############################################################################

keyframes = motion_io.extract_keyframes()
packed_motion = motion_io.pack_keyframes(*keyframes)

test_grid_5a = {
    "bvh_path": [
        "dataset/HumanML3D/bvh/test/001969_fromjoint100_a_man_walks_forward_then_turns_around_and_walks_back_before_facing_back_and_standing_still.bvh"
    ],
    "edit_mode": ["benchmark_sparse", "benchmark_clip"],
    "num_samples": [1],
    "foot_ik": [False],
    "jacobian_ik": [False],
    "editable_features": ["pos_rot", "pos_rot_vel"],
}
test_grid_5b = {
    "packed_motion": [None],
    "num_samples": [1],
    "foot_ik": [False],
    "jacobian_ik": [False],
    "editable_features": ["pos_rot", "pos_rot_vel"],
}

infer_by_grid_search(test_grid_5a, packed_motion)
infer_by_grid_search(test_grid_5b, packed_motion)
