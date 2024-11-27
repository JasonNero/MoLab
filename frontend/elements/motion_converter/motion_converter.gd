# class_name MotionConverter
extends Node

var _joint_order: Array[String] = [
	"Hips",
	"LeftUpLeg",
	"LeftLeg",
	"LeftFoot",
	"LeftToe",
	"RightUpLeg",
	"RightLeg",
	"RightFoot",
	"RightToe",
	"Spine",
	"Spine1",
	"Spine2",
	"Neck",
	"Head",
	"LeftShoulder",
	"LeftArm",
	"LeftForeArm",
	"LeftHand",
	"RightShoulder",
	"RightArm",
	"RightForeArm",
	"RightHand"
]


func results_to_animations(results: InferenceResults) -> Array[Animation]:
	var animations: Array[Animation] = []
	var result_count = results.root_positions.size()
	var key_count = results.root_positions[0].size()

	for variant_idx in range(result_count):
		var anim = Animation.new()
		anim.length = key_count / Globals.FPS

		var track_idx_hip = anim.add_track(Animation.TrackType.TYPE_POSITION_3D)
		anim.track_set_path(track_idx_hip, "%GeneralSkeleton:Hips")

		for key in range(key_count):
			var pos: Vector3 = Vector3(
				results.root_positions[variant_idx][key][0],
				results.root_positions[variant_idx][key][1],
				results.root_positions[variant_idx][key][2]
			)
			var time: float = key / Globals.FPS
			anim.track_insert_key(track_idx_hip, time, pos)

		for joint_id in range(_joint_order.size()):
			var joint_name = _joint_order[joint_id]
			var track_idx_joint = anim.add_track(Animation.TrackType.TYPE_ROTATION_3D)
			anim.track_set_path(track_idx_joint, "%GeneralSkeleton:{0}".format([joint_name]))

			for key in range(key_count):
				# TODO: GO ON HERE

				var euler: Vector3 = Vector3(
					deg_to_rad(results.joint_rotations[variant_idx][key][joint_id][0]),
					deg_to_rad(results.joint_rotations[variant_idx][key][joint_id][1]),
					deg_to_rad(results.joint_rotations[variant_idx][key][joint_id][2])
				)

				var basis: Basis = Basis.from_euler(euler, EULER_ORDER_YZX)
				var quat: Quaternion = basis.get_rotation_quaternion()

				# var quat: Quaternion = Quaternion.from_euler(euler)
				var time: float = key / Globals.FPS
				anim.track_insert_key(track_idx_joint, time, quat)

		animations.append(anim)

	return animations


# func animation_to_packed_motion(anim: Animation) -> Dictionary:
# 	pass
