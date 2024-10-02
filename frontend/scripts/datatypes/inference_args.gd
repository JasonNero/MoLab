class_name InferenceArgs
extends RefCounted

# Properties
var bvh_path: String = ""
var packed_motion: Dictionary = {}
var num_samples: int = 3
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

# Serialize the object to JSON
func to_json() -> String:
    var data = {
        "bvh_path": bvh_path,
        "packed_motion": packed_motion,
        "num_samples": num_samples,
        "jacobian_ik": jacobian_ik,
        "foot_ik": foot_ik,
        "unpack_randomness": unpack_randomness,
        "unpack_mode": unpack_mode
    }
    return JSON.stringify(data)

# Deserialize from JSON to create the object
func from_json(json_string: String) -> void:
    var data = JSON.parse_string(json_string)
    if data.error == OK:
        var dict = data.result
        packed_motion = dict.get("packed_motion", {})
        num_samples = dict.get("num_samples", 3)
        jacobian_ik = dict.get("jacobian_ik", false)
        foot_ik = dict.get("foot_ik", false)
        unpack_randomness = dict.get("unpack_randomness", 0.0)
        unpack_mode = dict.get("unpack_mode", "linear")
    else:
        print("Failed to parse JSON: ", data.error_string)
