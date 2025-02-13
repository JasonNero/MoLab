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

worker = None

# Get Gateway WebSocket URL from environment variable or default to 'localhost:8000'
BACKEND_HOST = os.getenv("GATEWAY_HOST", "localhost")
BACKEND_PORT = os.getenv("GATEWAY_PORT", "8000")
uri = f"ws://{BACKEND_HOST}:{BACKEND_PORT}/register_worker"


def setup_worker():
    """Starts the worker, loading the model checkpoint and arguments."""
    # Setup the MotionInferenceWorker
    # model_path = (
    #     Path(__file__).parent / "save" / "condmdi_random_joints" / "model000750000.pt"
    # )
    # logger.info("Using random joints model.")
    model_path = (
        Path(__file__).parent / "save" / "condmdi_random_frames" / "model000750000.pt"
    )
    logger.info("Using random frames model.")
    assert model_path.is_file(), f"Model checkpoint not found at [{model_path}]"
    model_args_path = model_path.parent / "args.json"
    with model_args_path.open("r") as file:
        model_dict = json.load(file)

    # Filter out only the model arguments (ignores `EvaluationOptions`)
    model_args = ModelArgs(**{
        k: v for k, v in model_dict.items() if k in ModelArgs.__dataclass_fields__
    })
    model_args.model_path = model_path
    model_args.num_repetitions = 1
    model_args.num_samples = 1

    global worker
    worker = MotionInferenceWorker("worker", model_args)


async def worker_logic(uri: str):
    """Connects to the gateway and waits for inference requests."""
    async with websockets.connect(uri) as websocket:
        logger.info("Worker connected to gateway")
        if __debug__:
            logger.info("Asserts are enabled!")
        else:
            logger.info("Asserts are disabled!")
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

                        del message["type"]  # This is a bit hacky
                        inference_args = InferenceArgs(**message)
                        result: InferenceResults = (
                            await asyncio.get_event_loop().run_in_executor(
                                None, worker.infer, inference_args
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
            worker.stop()


def main():
    setup_worker()
    asyncio.run(worker_logic(uri))
    worker.stop()


if __name__ == "__main__":
    main()
