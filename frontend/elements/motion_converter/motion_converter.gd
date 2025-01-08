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
		var nan_counter: int = 0

		var hip_pos_key: int = anim.track_find_key(hip_pos_track, frame / Globals.FPS, Animation.FIND_MODE_APPROX)

		if hip_pos_key == -1:
			# print("Hip key not found: ", frame)
			frame_data.append([NAN, NAN, NAN])
			nan_counter += 1
		else:
			var hip_pos: Vector3 = anim.track_get_key_value(hip_pos_track, hip_pos_key)
			frame_data.append([hip_pos.x, hip_pos.y, hip_pos.z])

		for bone_name in _joint_order:
			var bone_track: int = anim.find_track(
				NodePath("%GeneralSkeleton:{0}".format([bone_name])),
				Animation.TYPE_ROTATION_3D
			)
			if bone_track == -1:
				# print("Bone track not found: ", bone_name)
				frame_data.append([NAN, NAN, NAN])
				nan_counter += 1
				continue

			var bone_key: int = anim.track_find_key(
				bone_track,
				frame / Globals.FPS,
				Animation.FIND_MODE_APPROX  # Basically equal +- floating point error
			)
			if bone_key == -1:
				# print("Bone key not found: ", bone_name)
				frame_data.append([NAN, NAN, NAN])
				nan_counter += 1
				continue

			var quat: Quaternion = anim.track_get_key_value(bone_track, bone_key)
			var euler_rad: Vector3 = quat.get_euler(order)
			var euler_deg: Vector3 = Vector3(rad_to_deg(euler_rad.x), rad_to_deg(euler_rad.y), rad_to_deg(euler_rad.z))

			# NOTE: To be consistent with the template BVH, we sort the rotation values by ZYX,
			#		this has nothing to do with the euler rotation order.
			frame_data.append([euler_deg.z, euler_deg.y, euler_deg.x])

		if nan_counter == 23:
			print("Frame {0} has all NaNs".format([frame]))
			if frame == 0:
				push_error("First frame has all NaNs! Check the input data.")
			continue
		else:
			if nan_counter > 0:
				print("Frame {0} has {1} NaNs".format([frame, nan_counter]))
			packed_motion[frame] = frame_data

	return packed_motion
