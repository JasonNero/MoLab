import asyncio
import json
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from ray import serve

from models.condmdi.inference_worker import (
    InferenceArgs,
    InferenceResults,
    ModelArgs,
    MotionInferenceWorker,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Defines startup and shutdown behavior for the FastAPI application."""

    model_path = Path("./save/condmdi_random_joints/model000750000.pt")
    print("\n\nUsing random joints model\n\n")
    # model_path = Path("./save/condmdi_random_frames/model000750000.pt")
    # print("\n\nUsing random frames model\n\n")
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

    yield  # Startup done, waiting for shutdown

    worker.stop()


app = FastAPI(lifespan=lifespan, title="Motion Inference Server")


@serve.deployment(num_replicas=1)
@serve.ingress(app)
class FastAPIWrapper:
    @app.websocket("/infer")
    async def inference(self, websocket: WebSocket):
        await websocket.accept()
        try:
            while True:
                data = await websocket.receive_json()
                print("Received Job")

                inference_args = InferenceArgs(**data)
                result: InferenceResults = (
                    await asyncio.get_event_loop().run_in_executor(
                        None, worker.infer, inference_args
                    )
                )

                print("Finished Job")
                await websocket.send_json(result.model_dump())
        except WebSocketDisconnect as e:
            print(f"WebSocket closed: [{e.code}] {e.reason}")


handle = serve.run(FastAPIWrapper.bind(), blocking=True, name="MotionInferenceServer")
