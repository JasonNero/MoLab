class_name SourceFile
extends Source

@export_category("File Source")
@export_global_file var filepath: String

func _init(_name="untitled", _in_point=0, _out_point=100, _in_offset=0, _out_offset=0, _file="") -> void:
	super(_name, _in_point, _out_point, _in_offset, _out_offset)
	self.filepath = _file

# Override get_properties to include base properties and TTM-specific ones
func get_properties() -> Dictionary:
	# Get base properties from parent class
	var props = super.get_properties()

	# Add SourceFile-specific properties
	props["filepath"] = {
		"type": TYPE_STRING,
		"value": filepath,
		"hint": PROPERTY_HINT_FILE
	}

	return props

# Override set_property to handle the new properties
func set_property(property: String, value: Variant) -> void:
	set(property, value)

# Override apply to overlay the source animation on top of the target animation
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

	# TODO: For simpler processing, create a temporary trimmed animation from the source
	#		This could also already include the starting in origin.

	# TODO: Root Motion
	# 1. root_offset = target_anim `Hips` position at [override_start_sec - 1 frame]
	# 2. Move source_anim to Origin at [override_start_sec]
	# 3. Add root_offset.xz to source_anim Hips position at [override_start_sec]

	for source_track_idx in animation.get_track_count():
		var track_type := animation.track_get_type(source_track_idx)
		var track_path := animation.track_get_path(source_track_idx)

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
		key_count = animation.track_get_key_count(source_track_idx)
		for key_idx in key_count:
			var local_time := animation.track_get_key_time(source_track_idx, key_idx)
			if local_time < in_offset_sec or local_time > out_point_sec - in_point_sec - out_offset_sec:
				# Skip keyframes outside the inner range
				continue

			var value = animation.track_get_key_value(source_track_idx, key_idx)

			# Offset local_time by source in_point
			var global_time := local_time + in_point_sec

			# Insert the keyframe
			target_animation.track_insert_key(
				target_track_idx,
				global_time,
				value,
				# transition,
			)

	return target_animation


func _get_or_create_track(anim: Animation, track_path: NodePath, track_type: int) -> int:
	var track_idx := anim.find_track(track_path, track_type)
	if track_idx == -1:
		track_idx = anim.add_track(track_type)
		anim.track_set_path(track_idx, track_path)
	return track_idx
