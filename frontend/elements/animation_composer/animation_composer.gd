class_name AnimationComposer
extends Node

signal playback_time_changed(time: float)

var composition: Composition
var animation_player: AnimationPlayer

var current_animation: Animation = Animation.new()

# Configuration
const ANIMATION_LIBRARY_NAME := "composer"
const ANIMATION_NAME := "composer/latest"
const PLAYBACK_PROCESS_MODE := AnimationPlayer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS


# Using a local enum here because the native ones cant be converted to strings
enum TrackType {
	TYPE_VALUE = 0,
	TYPE_POSITION_3D = 1,
	TYPE_ROTATION_3D = 2,
	TYPE_SCALE_3D = 3,
	TYPE_BLEND_SHAPE = 4,
	TYPE_METHOD = 5,
	TYPE_BEZIER = 6,
	TYPE_AUDIO = 7,
	TYPE_ANIMATION = 8,
}


func initialize(p_composition: Composition, p_animation_player: AnimationPlayer) -> void:
	composition = p_composition
	animation_player = p_animation_player

	_configure_animation_player()
	_connect_signals()
	update_animation()

func _configure_animation_player() -> void:
	animation_player.callback_mode_process = PLAYBACK_PROCESS_MODE
	animation_player.playback_default_blend_time = 0
	animation_player.clear_queue()
	animation_player.add_animation_library(ANIMATION_LIBRARY_NAME, AnimationLibrary.new())

func _connect_signals() -> void:
	composition.source_modified.connect(_on_composition_changed)
	animation_player.animation_finished.connect(_on_animation_finished)

func update_animation() -> void:
	if current_animation:
		current_animation.clear()
	if composition.sources.size() == 0:
		return

	print("Initializing Flattened Animation with ", composition.sources[-1].name)
	# current_animation = composition.sources[-1].animation.duplicate()
	current_animation.resource_name = "latest"
	current_animation.loop = true
	current_animation.length = float(composition.get_frame_range()[1]) / Globals.FPS

	# Merge all source animations from bottom to top
	for i in range(composition.sources.size() - 1, -1, -1):
		var source := composition.sources[i]
		# print("Merging source: ", source.name)
		_merge_source_animation(current_animation, source)
		# break

	ResourceSaver.save(current_animation, "res://debug_latest_anim.tres")

	# Update animation player
	if animation_player.has_animation(ANIMATION_NAME):
		animation_player.get_animation_library(ANIMATION_LIBRARY_NAME).remove_animation(ANIMATION_NAME.split("/")[1])
	animation_player.get_animation_library(ANIMATION_LIBRARY_NAME).add_animation(ANIMATION_NAME.split("/")[1], current_animation)

	# Ensure we're at a valid position
	var current_time := get_current_time()
	if current_time > current_animation.length:
		seek(current_animation.length)


func _get_or_create_track(anim: Animation, track_path: NodePath, track_type: int) -> int:
	var track_idx := anim.find_track(track_path, track_type)
	if track_idx == -1:
		track_idx = anim.add_track(track_type)
		anim.track_set_path(track_idx, track_path)
	return track_idx

func _merge_source_animation(target: Animation, source: Source) -> void:
	var source_anim: Animation = source.animation
	if not source_anim:
		print("Skipping source without animation: ", source.name)
		return

	# NOTE: The source properties are all in frames, whereas
	# 		the `Animation` and `AnimationPlayer` use seconds.
	# Converting all frames to time (seconds)
	var in_point_sec := float(source.in_point) / Globals.FPS
	var out_point_sec := float(source.out_point) / Globals.FPS
	var in_offset_sec := float(source.in_offset) / Globals.FPS
	var out_offset_sec := float(source.out_offset) / Globals.FPS

	var override_start := in_point_sec + in_offset_sec
	var override_end := out_point_sec - out_offset_sec

	print("Merging into latest: ", source.name)
	print("\tin_point_sec: ", in_point_sec, "s out_point_sec: ", out_point_sec, "s")
	print("\toverride_start: ", override_start, "s (", override_start * Globals.FPS, "f)", " override_end: ", override_end, "s (", override_end * Globals.FPS, "f)")

	# Overwrite the target animation with the source animation
	for source_track_idx in source_anim.get_track_count():
		var track_type := source_anim.track_get_type(source_track_idx)
		var track_path := source_anim.track_get_path(source_track_idx)

		var target_track_idx := _get_or_create_track(target, track_path, track_type)

		# Make sure we disable "wrapping" to prevent sliding keyframes
		target.track_set_interpolation_loop_wrap(target_track_idx, false)

		# Remove keyframes in the target range before overwriting
		# Use reverse order to prevent index shifting
		var key_count := target.track_get_key_count(target_track_idx)
		var to_remove := []
		for key_idx in key_count:
			var key_time := target.track_get_key_time(target_track_idx, key_idx)
			if key_time >= override_start and key_time <= override_end:
				to_remove.append(key_idx)
		to_remove.reverse()
		for key_idx in to_remove:
			target.track_remove_key(target_track_idx, key_idx)

		# Copy and offset all keyframes
		key_count = source_anim.track_get_key_count(source_track_idx)
		for key_idx in key_count:
			var local_time := source_anim.track_get_key_time(source_track_idx, key_idx)
			if local_time < in_offset_sec or local_time > out_point_sec - in_point_sec - out_offset_sec:
				# Skip keyframes outside the inner range
				continue

			var value = source_anim.track_get_key_value(source_track_idx, key_idx)

			# Offset local_time by source in_point
			var global_time := local_time + in_point_sec

			# TODO: Root Transform "Offset" (to match prev_source last position at source.in_point)

			# Insert the keyframe
			target.track_insert_key(
				target_track_idx,
				global_time,
				value,
				# transition,
			)

# Playback Control
func play() -> void:
	if not animation_player.has_animation(ANIMATION_NAME):
		update_animation()
	animation_player.play(ANIMATION_NAME)

func pause() -> void:
	animation_player.pause()

func stop() -> void:
	animation_player.stop()
	seek(0)

func seek_frame(frame: int) -> void:
	seek(float(frame) / Globals.FPS)

func seek(time: float) -> void:
	if not animation_player.has_animation(ANIMATION_NAME):
		update_animation()
	animation_player.seek(time, true)
	playback_time_changed.emit(time)

func get_current_time() -> float:
	if animation_player.current_animation:
		return animation_player.current_animation_position
	else:
		return 0.0

func get_duration() -> float:
	return current_animation.length if current_animation else 0.0

# Signal Handlers
func _on_composition_changed(_source: Source) -> void:
	update_animation()

func _on_animation_finished(_anim_name: String) -> void:
	# Stop at end or loop based on your needs
	stop()

# Frame Update
func _process(_delta: float) -> void:
	if animation_player.is_playing():
		playback_time_changed.emit(get_current_time())
