"""Simple blocking client using `websockets`.

NOTE: Freezes Maya for the duration of the `recv` call.
"""

import sys
import json
from importlib import reload

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


keyframes = motion_io.extract_keyframes()
packed_motion = motion_io.pack_keyframes(*keyframes)
data = {
    # "bvh_path": "dataset/HumanML3D/bvh/test/011978_fromjoint100_a_person_walked_forward_by_changing_direcion_into_left_and_right.bvh",
    # "edit_mode": "benchmark_clip",
    "num_samples": 3,
    "packed_motion": packed_motion,
    "editable_features": "pos_rot",
    "text_prompt": "A person walking over stones",
}


result = infer(data)

motion_io.import_motions(
    result["root_positions"],
    result["joint_rotations"],
    start_frame=0,
    name="sample"
)

motion_io.import_motions(
    result["obs_root_positions"][:1],
    result["obs_joint_rotations"][:1],
    start_frame=0,
    name="obs",
)
