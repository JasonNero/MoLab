class_name Source
extends Resource

@export var name: String
@export var in_point: int
@export var out_point: int
@export var in_offset: int
@export var out_offset: int
@export var animation: Animation
@export var affects_post_range: bool = true

func _init(_name="untitled", _in_point=0, _out_point=10, _in_offset=0, _out_offset=0) -> void:
	self.name = _name
	self.in_point = _in_point
	self.out_point = _out_point
	self.in_offset = _in_offset
	self.out_offset = _out_offset

func get_animation_frames() -> int:
	if not animation:
		return 0
	else:
		return animation.length / Globals.FPS

func is_valid() -> bool:
	return out_point > in_point

# TODO: Rework this to use/override Object.get_property_list()
#		And display the properties panel using name.capitalize() as the title
func get_properties() -> Dictionary:
	return {
		"name": {"type": TYPE_STRING, "value": name, "text": "Name"},
		"in_point": {"type": TYPE_FLOAT, "value": in_point, "text": "In Point"},
		"out_point": {"type": TYPE_FLOAT, "value": out_point, "text": "Out Point"},
		"in_offset": {"type": TYPE_FLOAT, "value": in_offset, "text": "In Offset"},
		"out_offset": {"type": TYPE_FLOAT, "value": out_offset, "text": "Out Offset"},
		"affects_post_range": {"type": TYPE_BOOL, "value": affects_post_range, "text": "Affects Post-Range"},
	}

# TODO: Validate properties by overriding Object._validate_property()
func set_property(property: String, value: Variant) -> void:
	set(property, value)  # Using built-in setter


func apply(target_animation: Animation) -> Animation:
	if not animation:
		print("Skipping source without animation: ", name)
		return target_animation

	# Source properties are in [frames], Animations in [seconds]
	var in_point_sec := float(in_point) / Globals.FPS
	var out_point_sec := float(out_point) / Globals.FPS
	var in_offset_sec := float(in_offset) / Globals.FPS
	var out_offset_sec := float(out_offset) / Globals.FPS

	var override_start_sec := in_point_sec + in_offset_sec
	var override_end_sec := out_point_sec - out_offset_sec

	var trimmed_animation := _trim_and_center_animation()

	var target_hip_idx := target_animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	var hip_offset: Vector3 = Vector3.ZERO
	if target_hip_idx != -1:
		# Get the root offset at the start of the override range
		hip_offset = target_animation.position_track_interpolate(target_hip_idx, override_start_sec - 1.0/Globals.FPS)
		hip_offset.y = 0  # Ignore vertical offset

	for source_track_idx in trimmed_animation.get_track_count():
		var track_type := trimmed_animation.track_get_type(source_track_idx)
		var track_path := trimmed_animation.track_get_path(source_track_idx)

		var target_track_idx := _get_or_create_track(target_animation, track_path, track_type)

		# Make sure we disable "wrapping" to prevent sliding keyframes
		target_animation.track_set_interpolation_loop_wrap(target_track_idx, false)

		# Remove keyframes in the target range before overwriting
		# Use reverse order to prevent index shifting
		var key_count := target_animation.track_get_key_count(target_track_idx)
		var to_remove := []
		for key_idx in key_count:
			var key_time := target_animation.track_get_key_time(target_track_idx, key_idx)
			if key_time >= override_start_sec and key_time <= override_end_sec:
				to_remove.append(key_idx)
		to_remove.reverse()
		for key_idx in to_remove:
			target_animation.track_remove_key(target_track_idx, key_idx)

		# Copy and offset all keyframes
		key_count = trimmed_animation.track_get_key_count(source_track_idx)
		for key_idx in key_count:
			var local_time := trimmed_animation.track_get_key_time(source_track_idx, key_idx)

			# Skip keyframes outside the override range
			if local_time < in_offset_sec or local_time > out_point_sec - in_point_sec - out_offset_sec:
				continue

			var value = trimmed_animation.track_get_key_value(source_track_idx, key_idx)
			var global_time := local_time + in_point_sec

			# Root/Hip Motion offset
			if target_track_idx == target_hip_idx:
				value += hip_offset

			target_animation.track_insert_key(
				target_track_idx,
				global_time,
				value,
				# transition,
			)
	# affects_post_range = false
	if affects_post_range:
		target_hip_idx = target_animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
		hip_offset = Vector3.ZERO
		if target_hip_idx != -1:
			# Get the root offset at the end of the trimmed animation
			hip_offset = trimmed_animation.position_track_interpolate(target_hip_idx, trimmed_animation.length)
			hip_offset.y = 0  # Ignore vertical offset

			# Now also apply the Hip offset to all following keyframes
			for key_idx in target_animation.track_get_key_count(target_hip_idx):
				var key_time := target_animation.track_get_key_time(target_hip_idx, key_idx)
				if key_time < override_end_sec:
					continue
				var key_value: Vector3 = target_animation.track_get_key_value(target_hip_idx, key_idx)
				var new_value := key_value + hip_offset
				new_value.y = key_value.y  # Ignore vertical offset
				target_animation.track_set_key_value(target_hip_idx, key_idx, new_value)

	return target_animation


# Trim the source animation to the inner range and let it start at the origin.
func _trim_and_center_animation() -> Animation:
	var trimmed_animation := Animation.new()

	# Source properties are in [frames], Animations in [seconds]
	var in_offset_sec := float(in_offset) / Globals.FPS
	var out_offset_sec := float(out_offset) / Globals.FPS

	# Trimming the animation to the override range
	for track_idx in animation.get_track_count():
		var track_type := animation.track_get_type(track_idx)
		var track_path := animation.track_get_path(track_idx)

		var trimmed_track_idx := trimmed_animation.add_track(track_type)
		trimmed_animation.track_set_path(trimmed_track_idx, track_path)

		assert(track_idx == trimmed_track_idx, "Track index mismatch")  # Sanity check

		# Make sure we disable "wrapping" to prevent sliding keyframes
		trimmed_animation.track_set_interpolation_loop_wrap(trimmed_track_idx, false)

		# Copy and offset all keyframes
		var key_count := animation.track_get_key_count(track_idx)
		for key_idx in key_count:
			var original_time := animation.track_get_key_time(track_idx, key_idx)
			if original_time < in_offset_sec or original_time > animation.length - out_offset_sec:
				# Skip keyframes outside the override range
				continue

			var value = animation.track_get_key_value(track_idx, key_idx)

			# Begin at trim start
			var trimmed_time := original_time - in_offset_sec

			# Insert the keyframe
			trimmed_animation.track_insert_key(
				trimmed_track_idx,
				trimmed_time,
				value,
				# transition,
			)

	var hip_track_idx := trimmed_animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	var hip_key_count = trimmed_animation.track_get_key_count(hip_track_idx)

	if hip_track_idx == -1 or hip_key_count == 0:
		print("Source '", name, "' has no Hip Translation keyframes.")
	else:
		# Take the first XZ position keyframe and subtract it from all keyframes
		var first_key_idx := trimmed_animation.track_find_key(hip_track_idx, 0, Animation.FIND_MODE_APPROX)
		var first_key_value: Vector3
		if first_key_idx == -1:
			# Fall back to interpolated value fetched at time 0
			push_warning("Using interpolated position for Hip start for source '", name, "'")
			first_key_value = trimmed_animation.position_track_interpolate(hip_track_idx, 0)
		else:
			first_key_value = trimmed_animation.track_get_key_value(hip_track_idx, first_key_idx)

		# Subtract the first keyframe from all keyframes
		for key_idx in hip_key_count:
			var key_value: Vector3 = trimmed_animation.track_get_key_value(hip_track_idx, key_idx)
			var new_value := key_value - first_key_value
			new_value.y = key_value.y  # Ignore vertical offset
			trimmed_animation.track_set_key_value(hip_track_idx, key_idx, new_value)

	return trimmed_animation


func _get_or_create_track(anim: Animation, track_path: NodePath, track_type: int) -> int:
	var track_idx := anim.find_track(track_path, track_type)
	if track_idx == -1:
		track_idx = anim.add_track(track_type)
		anim.track_set_path(track_idx, track_path)
	return track_idx
