import asyncio
import json
import logging
import os
from pathlib import Path

import websockets

from molab_condmdi.inference_worker import (
    InferenceArgs,
    InferenceResults,
    ModelArgs,
    MotionInferenceWorker,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("worker")


class WebSocketWorker:
    def __init__(
        self, backend_host="localhost", backend_port=8000, checkpoint="random_frames"
    ):
        """Initialize the WebSocketWorker.

        Args:
            backend_host (str): The hostname of the backend server. Defaults to "localhost".
            backend_port (int): The port number of the backend server. Defaults to 8000.
            checkpoint (str): The name of the checkpoint to be used, current choices are
                "random_frames" (Default) or "random_joints".

        Attributes:
            inference_worker (None): Placeholder for the inference worker.
            uri (str): The WebSocket URI for registering the worker.
            checkpoint (str): The name of the checkpoint.
            checkpoint_path (Path): The path to the model checkpoint file.

        Raises:
            FileNotFoundError: If the model checkpoint file is not found at the specified path.
        """
        self.inference_worker: MotionInferenceWorker = None
        self.uri = f"ws://{backend_host}:{backend_port}/register_worker"
        self.checkpoint = checkpoint
        self.checkpoint_path = (
            Path(__file__).parent
            / "save"
            / f"condmdi_{checkpoint}"
            / "model000750000.pt"
        )
        if not self.checkpoint_path.is_file():
            raise FileNotFoundError(f"Model checkpoint not found at [{self.checkpoint_path}]")

    def setup(self):
        """Start the `MotionInferenceWorker`."""
        logger.info(f"This worker uses the {self.checkpoint} model.")
        model_args_path = self.checkpoint_path.parent / "args.json"
        with model_args_path.open("r") as file:
            model_dict = json.load(file)

        model_args = ModelArgs(**{
            k: v for k, v in model_dict.items() if k in ModelArgs.__dataclass_fields__
        })
        model_args.model_path = self.checkpoint_path
        model_args.num_repetitions = 1
        model_args.num_samples = 1

        self.inference_worker = MotionInferenceWorker(
            f"{self.checkpoint}_worker", model_args
        )

    async def serve(self):
        """Connect to the gateway and wait for inference requests."""
        async with websockets.connect(self.uri) as websocket:
            logger.info("Worker connected to gateway")
            if __debug__:
                logger.debug("Asserts are enabled!")
            else:
                logger.debug("Asserts are disabled!")
            try:
                while True:
                    try:
                        message = await websocket.recv()

                        if message == "ping":
                            continue

                        try:
                            message = json.loads(message)
                        except json.JSONDecodeError:
                            logger.exception(f"Failed to decode message:\n{message}")
                            await websocket.send("Failed to decode message")
                            continue

                        if message["type"] == "infer":
                            logger.info("Worker received inference request")

                            del message["type"]
                            inference_args = InferenceArgs(**message)
                            result: InferenceResults = (
                                await asyncio.get_event_loop().run_in_executor(
                                    None, self.inference_worker.infer, inference_args
                                )
                            )

                            logger.info("Worker finished inference")
                            await websocket.send(json.dumps(result.model_dump()))
                        else:
                            logger.error(f"Unknown message type:\n{message}")
                            await websocket.send("Unknown message type")

                    except websockets.ConnectionClosed:
                        logger.info("Connection to gateway closed")
                        break
            finally:
                self.inference_worker.stop()

    def run(self):
        self.setup()
        asyncio.run(self.serve())
        self.inference_worker.stop()


def main():
    WebSocketWorker(
        backend_host=os.getenv("GATEWAY_HOST", "localhost"),
        backend_port=os.getenv("GATEWAY_PORT", "8000"),
        checkpoint="random_frames",  # or "random_joints"
    ).run()


if __name__ == "__main__":
    main()
