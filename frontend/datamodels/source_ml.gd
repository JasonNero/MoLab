class_name SourceML
extends Source

enum MODELTYPE {RANDOM_FRAMES, RANDOM_JOINTS}

@export_category("ML Source")
@export_placeholder("A person ...") var text: String
@export var modeltype: MODELTYPE = MODELTYPE.RANDOM_FRAMES

@export_storage var animation_samples: Array[Animation] = []
@export var selected_sample: int = 0

@export_storage var is_dirty: bool = false
var do_process: bool = false
var _is_processing: bool = false


func _init(_name="untitled", _in_point=0, _out_point=100, _in_offset=0, _out_offset=0, _text="", _modeltype=MODELTYPE.RANDOM_FRAMES) -> void:
	super(_name, _in_point, _out_point, _in_offset, _out_offset)
	self.text = _text
	self.modeltype = _modeltype

# Override get_properties to include base properties and TTM-specific ones
func get_properties() -> Dictionary:
	# Get base properties from parent class
	var props = super.get_properties()

	# Add TTM-specific properties
	props["text"] = {
		"type": TYPE_STRING,
		"value": text,
		"text": "Prompt Text",
	}

	props["modeltype"] = {
		"type": TYPE_INT,
		"value": modeltype,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(MODELTYPE.keys())
	}

	props["selected_sample"] = {
		"type": TYPE_INT,
		"value": selected_sample,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(range(animation_samples.size()))
	}

	props["do_process"] = {
		"type": TYPE_CALLABLE,
		"value": do_process,
		"text": "Process"
	}
	return props

# Override set_property to handle the new properties
func set_property(property: String, value: Variant) -> void:
	match property:
		"name", "affects_post_range", "selected_sample", "do_process":
			# Handle properties that do not require re-processing
			set(property, value)
		_:
			# Handle properties that require re-processing
			set(property, value)
			is_dirty = true

func _on_result_received(results: InferenceResults):
	Backend.results_received.disconnect(_on_result_received)
	print("Source '", name, "' received results from Backend:")
	print(results)

	animation_samples = MotionConverter.results_to_animations(results)
	selected_sample = 0
	animation = animation_samples[selected_sample]
	is_dirty = false
	_is_processing = false

func process(target_animation: Animation) -> void:
	do_process = false
	_is_processing = true

	var inference_args = InferenceArgs.new()
	inference_args.num_samples = 3
	inference_args.text_prompt = text

	# TODO: Read the input motion from target_animation and _trim_and_center it to the in-out-range
	if in_offset > 0 or out_offset > 0:
		# TODO: Implement this
		push_error("PackedMotion Input for SourceML via in/out offsets not yet implemented!")

		var in_point_sec := float(in_point) / Globals.FPS
		var out_point_sec := float(out_point) / Globals.FPS
		var in_offset_sec := float(in_offset) / Globals.FPS
		var out_offset_sec := float(out_offset) / Globals.FPS
		# Trim&Center input animation to the full range
		# TODO: modify the trim function to take an animation (the target_animation) as input instead
		var trimmed_target_anim := _trim_and_center_animation(in_point_sec, out_point_sec)

		# Remove keyframes in the inner range
		for track_idx in trimmed_target_anim.get_track_count():
			var key_count := trimmed_target_anim.track_get_key_count(track_idx)
			var to_remove := []
			for key_idx in key_count:
				var key_time := trimmed_target_anim.track_get_key_time(track_idx, key_idx)
				if key_time >= in_offset_sec and key_time <= trimmed_target_anim.length - out_offset_sec:
					to_remove.append(key_idx)
			to_remove.reverse()
			for key_idx in to_remove:
				trimmed_target_anim.track_remove_key(track_idx, key_idx)

		var packed_motion = MotionConverter.animation_to_packed_motion(trimmed_target_anim)
		inference_args.packed_motion = packed_motion

	print("Building Request")

	Backend.results_received.connect(_on_result_received)
	Backend.infer(inference_args)


func apply(target_animation: Animation) -> Animation:
	if do_process and not _is_processing:
		process(target_animation)

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

	var trimmed_animation := _trim_and_center_animation(in_offset_sec, out_offset_sec)

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
		if target_hip_idx != -1 and target_animation.track_get_key_count(target_hip_idx) > 0:
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
