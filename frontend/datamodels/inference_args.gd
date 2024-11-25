class_name InferenceArgs
extends RefCounted

# Properties
var type: String = "infer"
var bvh_path: String = ""
var text_prompt: String = ""
var packed_motion: Dictionary = {}
var num_samples: int = 1
var jacobian_ik: bool = false
var foot_ik: bool = false
var unpack_randomness: float = 0.0
var _unpack_mode: String = "linear"
var unpack_mode: String:
    get:
        return _unpack_mode
    set(value):
        if value in ["step", "linear"]:
            _unpack_mode = value
        else:
            print("Invalid value for unpack_mode. Must be 'step' or 'linear'")

func to_dict() -> Dictionary:
    return {
        "type": type,
        "bvh_path": bvh_path,
        "text_prompt": text_prompt,
        "packed_motion": packed_motion,
        "num_samples": num_samples,
        "jacobian_ik": jacobian_ik,
        "foot_ik": foot_ik,
        "unpack_randomness": unpack_randomness,
        "unpack_mode": unpack_mode
    }

# Serialize the object to JSON
func to_json() -> String:
    return JSON.stringify(to_dict())

# Deserialize from JSON to create the object
static func from_json(json_string: String) -> InferenceArgs:
    var args = InferenceArgs.new()
    var data = JSON.parse_string(json_string)
    if data == null:
        print("Failed to parse JSON: ", data.error_string)
    else:
        args.type = data.get("type", "infer")
        args.bvh_path = data.get("bvh_path", "")
        args.text_prompt = data.get("text_prompt", "")
        args.packed_motion = data.get("packed_motion", {})
        args.num_samples = data.get("num_samples", 1)
        args.jacobian_ik = data.get("jacobian_ik", false)
        args.foot_ik = data.get("foot_ik", false)
        args.unpack_randomness = data.get("unpack_randomness", 0.0)
        args.unpack_mode = data.get("unpack_mode", "linear")
    return args
