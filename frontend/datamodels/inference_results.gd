class_name InferenceResults
extends RefCounted

# Properties
var root_positions: Array = []
var joint_rotations: Array = []
var obs_root_positions: Array = []
var obs_joint_rotations: Array = []

func to_dict() -> Dictionary:
    return {
        "root_positions": root_positions,
        "joint_rotations": joint_rotations,
        "obs_root_positions": obs_root_positions,
        "obs_joint_rotations": obs_joint_rotations
    }

func to_json() -> String:
    return JSON.stringify(to_dict())

static func from_json(json_string: String) -> InferenceResults:
    var results = InferenceResults.new()
    var data = JSON.parse_string(json_string)

    if data.error != OK:
        print("Failed to parse JSON: ", data.error_string)
    else:
        var dict = data.result
        results.root_positions = dict.get("root_positions", [])
        results.joint_rotations = dict.get("joint_rotations", [])
        results.obs_root_positions = dict.get("obs_root_positions", [])
        results.obs_joint_rotations = dict.get("obs_joint_rotations", [])
    return results
