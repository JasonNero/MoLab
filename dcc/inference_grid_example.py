"""MoLab Client to compare inference parameters combinations.

NOTE: Freezes Maya for the duration of the `recv` call.

# Usage:
1. Select Hip Bone of the source skeleton
2. Adapt the `test_grids` below
3. Run the script and wait for Maya to un-freeze
"""

import itertools
import time
from pprint import pprint

from molab_maya import motion_io
from molab_maya.client import MoLabClient

# Initialize the client
client = MoLabClient("ws://localhost:8000")


def infer_by_grid_search(grid: dict[str, list], packed_motion=None):
    """Takes a dictionary of lists. Each list is a parameter to search over.
    The search/test space is the cartesian product of all the lists.
    """

    product = list(itertools.product(*grid.values()))
    print(f"Running inference on {len(product)} parameter combinations.")
    print(f"This will take approx. {len(product) * 2} minutes on Apple M3.")
    time.sleep(2)  # Give Maya some time to breathe/print

    for i, params in enumerate(product):
        data = dict(zip(grid.keys(), params))
        if packed_motion and "packed_motion" in data:
            data["packed_motion"] = packed_motion

        print(f"\n========== Infer by Grid Search [{i+1}/{len(product)}] ==========")
        pprint(data, depth=2)
        print("================================================")

        client.infer_and_import(
            data, start_frame=0, name=f"gs{i}", import_observed=True
        )


###############################################################################

packed_motion = motion_io.extract_and_pack_keyframes()

# Usage with packed_motion
packed_motion_test_grid = {
    "packed_motion": [None],
    "num_samples": [1],
    "foot_ik": [False],
    "jacobian_ik": [False],
    "editable_features": ["pos_rot_vel"],
    "unpack_mode": ["linear"],
    "unpack_randomness": [0.0],
}
infer_by_grid_search(packed_motion_test_grid, packed_motion)
