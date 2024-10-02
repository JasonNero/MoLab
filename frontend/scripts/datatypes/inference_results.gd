class_name InferenceResults
extends RefCounted

# Properties
var root_positions: Array = []
var joint_rotations: Array = []
var obs_root_positions: Array = []
var obs_joint_rotations: Array = []

func to_json() -> String:
    var data = {
        "root_positions": root_positions,
        "joint_rotations": joint_rotations,
        "obs_root_positions": obs_root_positions,
        "obs_joint_rotations": obs_joint_rotations
    }
    return JSON.stringify(data)

func from_json(json_string: String) -> void:
    var data = JSON.parse_string(json_string)
    if data.error == OK:
        var dict = data.result
        root_positions = dict.get("root_positions", [])
        joint_rotations = dict.get("joint_rotations", [])
        obs_root_positions = dict.get("obs_root_positions", [])
        obs_joint_rotations = dict.get("obs_joint_rotations", [])
    else:
        print("Failed to parse JSON: ", data.error_string)
