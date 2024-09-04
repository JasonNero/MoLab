import asyncio
import json
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from serve.inference_worker import InferenceArgs, ModelArgs, MotionInferenceWorker

MOCK = True

mocked_result = np.load(
    "save/results/condmdi_random_joints/condsamples000750000__benchmark_clip_T=40_CI=0_CRG=0_KGP=1.0_seed10/results.npy",
    allow_pickle=True,
).item()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Defines startup and shutdown behavior for the FastAPI application."""

    model_path = Path("./save/condmdi_random_joints/model000750000.pt")
    assert model_path.is_file(), f"Model checkpoint not found at [{model_path}]"

    model_args_path = model_path.parent / "args.json"
    with model_args_path.open("r") as file:
        model_dict = json.load(file)

    # Filter out only the model arguments (ignores `EvaluationOptions`)
    model_args = ModelArgs(
        **{k: v for k, v in model_dict.items() if k in ModelArgs.__dataclass_fields__}
    )
    model_args.model_path = model_path
    model_args.num_repetitions = 1
    model_args.num_samples = 1

    global worker
    worker = MotionInferenceWorker("worker", model_args)

    yield

    worker.stop()


app = FastAPI(lifespan=lifespan, title="Motion Inference Server")


@app.post(
    "/resolve_args",
    response_model=InferenceArgs,
    description="Resolve the arguments for the inference.",
)
async def resolve_args(args: dict):
    return InferenceArgs(**args)


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_json()
            print(f"Received:\n{data}")

            inference_args = InferenceArgs(**data)

            if MOCK:
                result = mocked_result
            else:
                result = await asyncio.get_event_loop().run_in_executor(
                    None, worker.infer, inference_args
                )
            result = {
                k: v.tolist() if hasattr(v, "tolist") else v for k, v in result.items()
            }

            print(f"Finished:\n{inference_args}")
            await websocket.send_text(f"Finished:\n{inference_args}")
            await websocket.send_json(result)
    except WebSocketDisconnect as e:
        print(f"WebSocket closed. {e.code}: {e.reason}")
        print(e)


if __name__ == "__main__":
    # uvicorn.run(app, host="0.0.0.0", port=8000)
    uvicorn.run(app, host="127.0.0.1", port=8000)

    # TODO: Allow Ctrl+C to stop the worker inside the event loop
