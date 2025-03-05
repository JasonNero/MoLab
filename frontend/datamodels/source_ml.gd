class_name SourceML
extends Source

enum MODELTYPE {RANDOM_FRAMES, RANDOM_JOINTS}

@export_category("ML Source")
@export_placeholder("A person ...") var text: String
@export var modeltype: MODELTYPE = MODELTYPE.RANDOM_FRAMES

@export var animation_samples: Array[Animation] = []
@export var selected_sample: int = 0

@export_storage var is_dirty: bool = false
var do_process: bool = false
var _is_processing: bool = false


func _init(_name="untitled", _in_point=0, _out_point=196, _in_offset=0, _out_offset=0, _text="", _modeltype=MODELTYPE.RANDOM_FRAMES) -> void:
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

	# TODO: Un-comment once modeltype switching is implemented in the backend/worker
	# props["modeltype"] = {
	# 	"type": TYPE_INT,
	# 	"value": modeltype,
	# 	"hint": PROPERTY_HINT_ENUM,
	# 	"hint_string": ",".join(MODELTYPE.keys())
	# }

	var name_hints = []
	for anim in animation_samples:
		name_hints.append(anim.resource_name)
	props["selected_sample"] = {
		"type": TYPE_INT,
		"value": selected_sample,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(name_hints)
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
	if Globals.DEBUG:
		# Dump to Godot log file for debugging
		print(results)

	animation_samples = MotionConverter.results_to_animations(results)
	animation = animation_samples[selected_sample]
	is_dirty = false
	_is_processing = false

func process(target_animation: Animation) -> void:
	do_process = false
	_is_processing = true

	var inference_args = InferenceArgs.new()
	inference_args.num_samples = 3
	inference_args.text_prompt = text

	if in_offset > 0 or out_offset > 0:
		var in_point_sec := float(in_point) / Globals.FPS
		var out_point_sec := float(out_point) / Globals.FPS
		var in_offset_sec := float(in_offset) / Globals.FPS
		var out_offset_sec := float(out_offset) / Globals.FPS

		# Trim&Center input animation to the full range
		var trimmed_target_anim := _trim_and_center_animation(in_point_sec, out_point_sec, target_animation)

		# Remove keyframes in the inner range.
		# We can use the same in/out offsets as for the native clip,
		# since the local time ranges match after trimming.
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

		if Globals.DEBUG:
			ResourceSaver.save(trimmed_target_anim, "res://tmp/debug_trimmed_target_anim.tres")

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

	animation = animation_samples[selected_sample]

	# Source properties are in [frames], Animations in [seconds]
	var in_point_sec := float(in_point) / Globals.FPS
	var out_point_sec := float(out_point) / Globals.FPS
	var in_offset_sec := float(in_offset) / Globals.FPS
	var out_offset_sec := float(out_offset) / Globals.FPS

	# Local to the animation clip
	var local_in_sec := in_offset_sec
	var local_out_sec := out_point_sec - in_point_sec - out_offset_sec

	# Global to the full timeline
	var global_start_sec := in_point_sec + in_offset_sec
	var global_end_sec := out_point_sec - out_offset_sec

	var target_hip_idx := target_animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	var hip_offset: Vector3 = Vector3.ZERO
	if target_hip_idx != -1:
		# Get the root offset at the start of the override range
		hip_offset = target_animation.position_track_interpolate(target_hip_idx, in_point_sec - 1.0/Globals.FPS)
		hip_offset.y = 0  # Ignore vertical offset
		if Globals.DEBUG:
			print("{0} Hip offset (in_range):   {1}".format([name, hip_offset]))

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
			if key_time >= global_start_sec and key_time <= global_end_sec:
				to_remove.append(key_idx)
		to_remove.reverse()
		for key_idx in to_remove:
			target_animation.track_remove_key(target_track_idx, key_idx)

		# Copy and offset all keyframes
		key_count = animation.track_get_key_count(source_track_idx)
		for key_idx in key_count:
			var local_time := animation.track_get_key_time(source_track_idx, key_idx)

			# Skip keyframes outside the override range
			if local_time < local_in_sec or local_time > local_out_sec:
				continue

			var value = animation.track_get_key_value(source_track_idx, key_idx)
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

	# Move all following keyframes to continue from where this source ends
	if affects_post_range:
		target_hip_idx = target_animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
		var post_hip_offset := Vector3.ZERO
		if target_hip_idx != -1 and target_animation.track_get_key_count(target_hip_idx) > 0:
			# Calculate the offset by comparing two adjacent keyframes
			# TODO: Double check this, looks sketchy
			var current_hip_pos = target_animation.position_track_interpolate(target_hip_idx, global_end_sec)
			post_hip_offset = current_hip_pos - target_animation.position_track_interpolate(target_hip_idx, global_end_sec + 1.0/Globals.FPS)
			post_hip_offset.y = 0  # Ignore vertical offset
			if Globals.DEBUG:
				print("{0} Hip offset (post_range): {1}".format([name, post_hip_offset]))

			# Propagate the offset to all keyframes after the override range
			for key_idx in target_animation.track_get_key_count(target_hip_idx):
				var key_time := target_animation.track_get_key_time(target_hip_idx, key_idx)
				if key_time < global_end_sec:
					continue
				var key_value: Vector3 = target_animation.track_get_key_value(target_hip_idx, key_idx)
				var new_value := key_value + post_hip_offset
				target_animation.track_set_key_value(target_hip_idx, key_idx, new_value)

	return target_animation
