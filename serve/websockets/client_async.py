"""Simple async client using `websockets`.

NOTE: Still freezes Maya.
"""

import json
import asyncio
from websockets.asyncio.client import connect

async def test():
    async with connect("ws://localhost:8000/infer", max_size=2**21) as websocket:
        data = {
            "bvh_path": "sample/dummy.bvh",
            "text_prompt": "Autodesk walks into a bar"
        }
        print(f"Sending:\n{data}")
        await websocket.send(json.dumps(data))
        print("Waiting for response...")

        message = await websocket.recv()
        print(f"Received:\n{message}")

# asyncio.new_event_loop().run_until_complete(hello())
asyncio.run(test(), debug=True)
