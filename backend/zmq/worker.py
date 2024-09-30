import json
from pathlib import Path

import numpy as np
import zmq

from ..inference_worker import InferenceArgs, ModelArgs, MotionInferenceWorker

MOCK = True

mocked_result = np.load(
    "save/results/condmdi_random_joints/condsamples000750000__benchmark_clip_T=40_CI=0_CRG=0_KGP=1.0_seed10/results.npy",
    allow_pickle=True,
).item()


def setup_model() -> MotionInferenceWorker:
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

    return MotionInferenceWorker("worker", model_args)


if __name__ == "__main__":
    context = zmq.Context()
    socket = context.socket(zmq.REP)
    # socket.connect("tcp://localhost:5560")
    socket.connect("ipc://backend")

    worker = setup_model()
    print("Model setup complete")

    try:
        while True:
            data = socket.recv_json()
            print(f"Received request: {data}")
            if MOCK:
                result = mocked_result
            else:
                result = worker.infer(InferenceArgs(**data))
            result = {
                k: v.tolist() if hasattr(v, "tolist") else v for k, v in result.items()
            }
            socket.send_json(result)
    except KeyboardInterrupt:
        worker.stop()
        socket.close()
        context.term()
