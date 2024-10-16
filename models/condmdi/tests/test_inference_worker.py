import json
import os
from pathlib import Path

import pytest

from molab_condmdi.inference_worker import (
    InferenceArgs,
    InferenceResults,
    ModelArgs,
    MotionInferenceWorker,
)


@pytest.fixture(scope="session", autouse=True)
def working_dir():
    working_dir = Path(__file__).parent.parent / "molab_condmdi"
    print(f"Setting working directory: {working_dir}")
    os.chdir(working_dir)


@pytest.fixture(scope="session")
def worker():
    # Load model
    model_path = Path(".") / "save" / "condmdi_random_joints" / "model000750000.pt"
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

    worker = MotionInferenceWorker("worker", model_args)
    yield worker
    worker.stop()


@pytest.mark.expensive
@pytest.mark.parametrize(
    "use_bvh, use_packed_motion, text",
    [
        pytest.param(False, False, "", id="unconditional"),
        pytest.param(True, False, "", id="bvh"),
        pytest.param(False, True, "", id="packed"),
        pytest.param(False, False, "Dance like nobody's watching", id="text"),
        pytest.param(True, False, "Dance like nobody's watching", id="bvh_text"),
        pytest.param(False, True, "Dance like nobody's watching", id="packed_text"),
    ],
)
def test_inference(worker: MotionInferenceWorker, use_bvh: bool, use_packed_motion: bool, text: str):
    """Naive test to check if the worker can infer without crashing.
    TODO: Add more meaningful tests, e.g. test the alignment with the `packed_motion`.
    TODO: Also override the output folder with a temporary directory (pytest fixture?).
    """
    packed_motion = {
        "0": [
            [0.006335, 0.925889, 0.022782],
            [-1.848952, 5.855419, -2.209308],
            [-2.225391, 0.251401, 2.091639],
            [-1.218372, -0.323186, 12.9199],
            [7.476767, 15.311409000000001, 1.712001],
            [0.0, 0.0, 0.0],
            [-2.184482, 1.651783, -23.240063],
            [-2.814711, 1.391872, 20.864488],
            [4.163708, 2.049498, 16.159805],
            [0.0, 0.0, 0.0],
            [3.729861, -0.337432, 4.422964],
            [2.408384, -1.4252, 3.27613],
            [-9.129623, -1.656823, 3.135745],
            [13.112406, -5.187206, -21.793815],
            [0.0, 0.0, 0.0],
            [-11.362097, -26.660376, 10.556817],
            [-51.782502, -43.877115, 14.017005],
            [132.977088, -62.445882, -104.782485],
            [0.0, 0.0, 0.0],
            [10.967079, 12.768552, 5.388521],
            [67.233545, 46.770885, 23.864491],
            [-125.065474, 57.771444, -84.861314],
            [0.0, 0.0, 0.0],
        ],
        "3": [
            [-0.005397, 0.923839, 0.038262],
            [-2.944292, 11.688877, -0.744433],
            [1.330347, -0.54384, -6.42566],
            [-2.461061, -1.037096, 25.45655],
            [5.155187, 11.443451, 3.14162],
            [0.0, 0.0, 0.0],
            [-1.958387, 1.366517, -22.168222],
            [-0.577779, 0.385054, 18.883832],
            [0.015543, -3.8655960000000005, 14.135998],
            [0.0, 0.0, 0.0],
            [3.4149730000000003, -0.55504, 6.905263],
            [1.382484, -0.791695, 1.400716],
            [-7.933509000000001, 3.7116560000000005, 2.637238],
            [15.413932000000003, -4.118027, -28.096708],
            [0.0, 0.0, 0.0],
            [-9.153748, -27.823949000000002, 9.350787],
            [-43.505833, -49.495025, 12.898866],
            [64.612952, -57.545172, -38.580461],
            [0.0, 0.0, 0.0],
            [10.838178, 14.427333, 7.570341],
            [45.742547, 54.182692, 18.629589],
            [-70.799916, 42.813622, -24.305144],
            [0.0, 0.0, 0.0],
        ],
        "4": [
            [-0.001765, 0.925816, 0.054307],
            [-3.725732, 12.670698, -2.237916],
            [4.608602, -0.474464, -6.318524],
            [-5.343978, -0.430467, 28.755527000000004],
            [12.128289, 23.607741, 10.015787],
            [0.0, 0.0, 0.0],
            [-0.879221, 1.500142, -21.414124],
            [-1.14147, 0.476827, 21.571616],
            [-0.540815, -5.032799, 15.559959],
            [0.0, 0.0, 0.0],
            [3.697301, -0.667363, 8.050449],
            [0.529855, -0.299849, 0.591786],
            [-7.173179000000001, 6.867548, 3.730258],
            [16.663089000000003, -4.834545, -26.58799],
            [0.0, 0.0, 0.0],
            [-8.517065, -28.319879000000004, 8.938752],
            [-31.162397000000002, -46.34815, 7.183754999999999],
            [52.002, -53.22641500000001, -28.400572000000004],
            [0.0, 0.0, 0.0],
            [9.081599, 16.898637, 8.935075],
            [28.47988, 50.958105, 9.339571],
            [-62.39294000000001, 46.62553, -22.598966],
            [0.0, 0.0, 0.0],
        ],
        "9": [
            [0.008035, 0.880018, 0.034304],
            [-2.27324, 24.479031, -4.485215],
            [7.304753, -0.781987, -10.104969],
            [-8.509794, -2.191417, 41.200228],
            [5.749923, 6.93057, -8.615016],
            [0.0, 0.0, 0.0],
            [-9.876022, -2.184774, -28.880068999999995],
            [5.098005, -6.16919, 43.525683],
            [-4.680638, -11.334446, 6.293945],
            [0.0, 0.0, 0.0],
            [3.232715, -0.610529, 7.64939],
            [-6.456206, 2.968811, -1.032531],
            [-3.360464, 18.495897, 5.631643],
            [23.504173, -9.795774, -19.990481],
            [0.0, 0.0, 0.0],
            [-5.656359, -8.609517, -0.31699600000000006],
            [-9.048457, -35.650475, -0.76012],
            [99.236589, -30.058303000000002, -45.053273],
            [0.0, 0.0, 0.0],
            [-5.406511, 13.903595, 4.479021],
            [9.39165, 15.831369999999998, -0.41817],
            [-14.650218000000002, 10.990762, -0.079215],
            [0.0, 0.0, 0.0],
        ],
        "10": [
            [0.004019, 0.872268, 0.025836],
            [-1.755083, 27.3451, -2.633481],
            [7.145027000000001, -1.07325, -13.17809],
            [-7.836206, -3.479632, 44.087649],
            [5.176777, 0.49769599999999997, -14.886387000000001],
            [0.0, 0.0, 0.0],
            [-10.852122, -3.225971, -31.103845],
            [5.80187, -7.921004000000001, 46.706103],
            [-6.359201, -14.977151000000001, 2.76627],
            [0.0, 0.0, 0.0],
            [3.435323, -0.5459680000000001, 6.583863],
            [-9.047144, 3.9601350000000006, -2.3822130000000006],
            [-2.988933, 18.627451000000004, 5.638191],
            [22.962958, -9.383703, -19.590579],
            [0.0, 0.0, 0.0],
            [-8.58717, -5.944162, -2.686332],
            [-3.7354569999999994, -35.300409, -2.001034],
            [102.827854, -21.3613, -35.058615],
            [0.0, 0.0, 0.0],
            [-3.672455, 9.356965, 3.259471],
            [12.307579, 7.272943, -1.152276],
            [-10.127301000000001, 9.465788, 0.134461],
            [0.0, 0.0, 0.0],
        ],
    }
    infer_dict: dict = {
        "num_samples": 1,
    }

    if use_packed_motion:
        infer_dict["packed_motion"] = packed_motion
    elif use_bvh:
        infer_dict["bvh_path"] = "sample/dummy.bvh"

    if text:
        infer_dict["text_prompt"] = text

    result = worker.infer(InferenceArgs(**infer_dict))
    assert result is not None
    return True
