import sys

import zmq

#  Prepare our context and sockets
context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect("tcp://localhost:5559")

name = sys.argv[1] if len(sys.argv) > 1 else "Client 1"

try:
    print("Sending request...")
    socket.send_json({
        "bvh_path": "sample/dummy.bvh",
        "text_prompt": f"{name} walks into a bar"
    })
    message = socket.recv()
    print(f"Received reply:\n{message}")

except KeyboardInterrupt:
    socket.close()
    context.term()
