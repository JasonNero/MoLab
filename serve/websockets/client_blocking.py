"""Simple blocking client using `websockets`.

NOTE: Freezes Maya for the duration of the `recv` call.
"""

import json
from websockets.sync.client import connect

def test():
    with connect("ws://localhost:8000/infer", max_size=2**21) as websocket:
        data = {
            "bvh_path": "sample/dummy.bvh",
            "text_prompt": "Autodesk walks into a bar"
        }
        print(f"Sending:\n{data}")
        websocket.send(json.dumps(data))
        print("Waiting for response...")

        message = websocket.recv()
        print(f"Received:\n{message}")

test()
