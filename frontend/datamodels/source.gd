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
	print("Base Source has no apply method.")
	return target_animation


# Trim the source animation to the inner range and let it start at the origin.
static func _trim_and_center_animation(local_in_sec: float, local_out_sec: float, animation: Animation) -> Animation:
	var trimmed_animation := Animation.new()

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
			var key_sec := animation.track_get_key_time(track_idx, key_idx)
			if key_sec < local_in_sec and local_in_sec - key_sec > 0.01:
				# Skip keyframes outside the override range
				# The 0.01 is to circumvent floating point errors
				continue
			elif key_sec > local_out_sec:
				# Skip keyframes outside the override range
				continue

			var value = animation.track_get_key_value(track_idx, key_idx)

			# Begin at trim start
			var trimmed_time := key_sec - local_in_sec

			# Insert the keyframe
			trimmed_animation.track_insert_key(
				trimmed_track_idx,
				trimmed_time,
				value,
				# transition,
			)

	var hip_track_idx := trimmed_animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	var hip_key_count = trimmed_animation.track_get_key_count(hip_track_idx)

	if hip_track_idx == -1:
		print("Source has not Hip Translation track.")
	elif hip_key_count == 0:
		print("Source has no Hip Translation keyframes.")
	else:
		# Take the first XZ position keyframe and subtract it from all keyframes
		var first_key_idx := trimmed_animation.track_find_key(hip_track_idx, 0, Animation.FIND_MODE_APPROX)
		var first_key_value: Vector3
		if first_key_idx == -1:
			# Fall back to interpolated value fetched at time 0
			push_warning("Using interpolated position for Hip start for source.")
			first_key_value = trimmed_animation.position_track_interpolate(hip_track_idx, 0)
		else:
			first_key_value = trimmed_animation.track_get_key_value(hip_track_idx, first_key_idx)

		# Subtract the first keyframe from all keyframes
		for key_idx in hip_key_count:
			var key_value: Vector3 = trimmed_animation.track_get_key_value(hip_track_idx, key_idx)
			var new_value := key_value - first_key_value
			new_value.y = key_value.y  # Ignore vertical offset
			trimmed_animation.track_set_key_value(hip_track_idx, key_idx, new_value)

	print("Animation trimmed to range: ", local_in_sec, " - ", local_out_sec)
	trimmed_animation.length = local_out_sec - local_in_sec
	return trimmed_animation


func _get_or_create_track(anim: Animation, track_path: NodePath, track_type: int) -> int:
	var track_idx := anim.find_track(track_path, track_type)
	if track_idx == -1:
		track_idx = anim.add_track(track_type)
		anim.track_set_path(track_idx, track_path)
	return track_idx
