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

# var order: int = EULER_ORDER_YZX
var order: int = EULER_ORDER_ZYX

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
				var euler: Vector3 = Vector3(
					deg_to_rad(results.joint_rotations[variant_idx][key][joint_id][0]),
					deg_to_rad(results.joint_rotations[variant_idx][key][joint_id][1]),
					deg_to_rad(results.joint_rotations[variant_idx][key][joint_id][2])
				)

				var basis: Basis = Basis.from_euler(euler, order)
				var quat: Quaternion = basis.get_rotation_quaternion()

				# var quat: Quaternion = Quaternion.from_euler(euler)
				var time: float = key / Globals.FPS
				anim.track_insert_key(track_idx_joint, time, quat)

		animations.append(anim)

	return animations


func animation_to_packed_motion(anim: Animation) -> Dictionary:
	# This returns a mapping of frame_idx to a list of joint rotations
	# E.g.:
	# {
	# 	1: [
	# 		[0, 0, 0],
	# 		[90, 0, 0],
	# 		...
	# 		[170, 45, -90]
	# 	],
	# 	2: ...
	# }

	var frame_count = int(anim.length * Globals.FPS)
	assert(frame_count < 197, "Frame count exceeds 197, this is not supported by the model.")

	var hip_pos_track: int = anim.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)

	var packed_motion: Dictionary = {}
	for frame in range(frame_count):
		var frame_data: Array = []

		var hip_pos_key: int = anim.track_find_key(hip_pos_track, frame / Globals.FPS, Animation.FIND_MODE_APPROX)
		var hip_pos: Vector3 = anim.track_get_key_value(hip_pos_track, hip_pos_key)
		frame_data.append([hip_pos.x, hip_pos.y, hip_pos.z])

		for bone_name in _joint_order:
			var bone_track: int = anim.find_track(NodePath("%GeneralSkeleton:{0}".format([bone_name])), Animation.TYPE_ROTATION_3D)
			var bone_key: int = anim.track_find_key(bone_track, frame / Globals.FPS, Animation.FIND_MODE_APPROX)
			var quat: Quaternion = anim.track_get_key_value(bone_track, bone_key)
			var euler: Vector3 = quat.get_euler(order)

			frame_data.append([rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)])

		packed_motion[frame] = frame_data

	return packed_motion
