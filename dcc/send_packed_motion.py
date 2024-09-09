"""Simple blocking client using `websockets`.

NOTE: Freezes Maya for the duration of the `recv` call.
"""

import sys
import json

try:
    from websockets.sync.client import connect
except ImportError as e:
    print("Please install the `websockets` package for the DCC python!")
    raise e

# TODO: Remove this
sys.path.append("/Users/jason/repos/diffusion-motion-inbetweening")

if sys.modules.get("maya"):
    from dcc.maya import export_keyframes
elif sys.modules.get("bpy"):
    from dcc.blender import export_keyframes


def infer(packed_motion):
    with connect("ws://localhost:8000/infer", max_size=2**21) as websocket:
        data = {
            "packed_motion": packed_motion,
            # "text_prompt": "Autodesk walks into a bar",
        }

        print(f"Sending:\n{data}")
        websocket.send(json.dumps(data))
        print("Waiting for response...")

        message = websocket.recv()
        result = json.loads(message)
        print(f"Received:\n{result}")

    return result["motions"]


keyframes = export_keyframes.extract_keyframes()
packed_motion = export_keyframes.pack_keyframes(*keyframes)
generated_motions = infer(packed_motion)


# TODO: Duplicate the source skeleton and apply the sampled motions

