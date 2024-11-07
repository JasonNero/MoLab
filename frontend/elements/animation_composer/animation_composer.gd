# animation_composer.gd
class_name AnimationComposer
extends Node

signal playback_time_changed(time: int)

var composition: Composition
var animation_player: AnimationPlayer

var current_animation: Animation

# Configuration
const ANIMATION_LIBRARY_NAME := "composer"
const ANIMATION_NAME := "composition"
const PLAYBACK_PROCESS_MODE := AnimationPlayer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

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
	pass
	# current_animation = Animation.new()

	# # Merge all source animations
	# for source in composition.sources:
	# 	_merge_source_animation(current_animation, source)

	# print(animation_player.get_animation_library_list())

	# # Update animation player
	# if animation_player.has_animation(ANIMATION_NAME):
	# 	animation_player.get_animation_library(ANIMATION_LIBRARY_NAME).remove_animation(ANIMATION_NAME)
	# animation_player.get_animation_library(ANIMATION_LIBRARY_NAME).add_animation(ANIMATION_NAME, current_animation)

	# # Ensure we're at a valid position
	# var current_time := get_current_time()
	# if current_time > current_animation.length:
	# 	seek(0)

func _merge_source_animation(target: Animation, source: Source) -> void:
	var source_anim: Animation = source.animation
	if not source_anim:
		return

	# Copy all tracks from source animation
	for track_idx in source_anim.get_track_count():
		var track_type := source_anim.track_get_type(track_idx)
		var track_path := source_anim.track_get_path(track_idx)

		# Create new track in target animation
		var new_track_idx := target.add_track(track_type)
		target.track_set_path(new_track_idx, track_path)

		# Copy and offset all keyframes
		var key_count := source_anim.track_get_key_count(track_idx)
		for key_idx in key_count:
			var time := source_anim.track_get_key_time(track_idx, key_idx)
			var value = source_anim.track_get_key_value(track_idx, key_idx)
			var transition := source_anim.track_get_key_transition(track_idx, key_idx)

			# Offset time by source in_point
			var new_time := time + source.in_point

			# Handle blending if needed
			if time < source.in_offset:
				value = _blend_with_previous_value(
					target,
					new_track_idx,
					new_time,
					value,
					time / source.in_offset
				)
			elif time > (source.get_animation_frames() - source.out_offset):
				var blend_factor := (source.get_animation_frames() - time) / source.out_offset
				value = _blend_with_next_value(
					target,
					new_track_idx,
					new_time,
					value,
					blend_factor
				)

			# Insert the keyframe
			target.track_insert_key(
				new_track_idx,
				new_time,
				value,
				transition,
			)

func _blend_with_previous_value(
	anim: Animation,
	track_idx: int,
	time: float,
	value: Variant,
	blend_factor: float
) -> Variant:
	var prev_key := _find_previous_key(anim, track_idx, time)
	if prev_key == null:
		return value

	return _blend_values(prev_key.value, value, blend_factor)

func _blend_with_next_value(
	anim: Animation,
	track_idx: int,
	time: float,
	value: Variant,
	blend_factor: float
) -> Variant:
	var next_key := _find_next_key(anim, track_idx, time)
	if next_key == null:
		return value

	return _blend_values(value, next_key.value, 1.0 - blend_factor)

func _find_previous_key(anim: Animation, track_idx: int, time: float) -> Dictionary:
	var key_count := anim.track_get_key_count(track_idx)
	var prev_key = null

	for i in key_count:
		var key_time := anim.track_get_key_time(track_idx, i)
		if key_time >= time:
			break
		prev_key = {
			"time": key_time,
			"value": anim.track_get_key_value(track_idx, i)
		}

	return prev_key

func _find_next_key(anim: Animation, track_idx: int, time: float) -> Dictionary:
	var key_count := anim.track_get_key_count(track_idx)

	for i in key_count:
		var key_time := anim.track_get_key_time(track_idx, i)
		if key_time > time:
			return {
				"time": key_time,
				"value": anim.track_get_key_value(track_idx, i)
			}

	return {}

func _blend_values(a: Variant, b: Variant, t: float) -> Variant:
	# Handle different value types
	if a is float:
		return lerp(a, b, t)
	elif a is Vector2:
		return a.lerp(b, t)
	elif a is Vector3:
		return a.lerp(b, t)
	elif a is Quaternion:
		return a.slerp(b, t)
	elif a is Color:
		return a.lerp(b, t)

	# Default to no blending for unsupported types
	return a

func _get_previous_value(track_path: String, time: float) -> Variant:
	# Find the previous keyframe value in any source that affects this track
	# Implementation depends on your needs
	return null  # Replace with actual implementation

func _get_next_value(track_path: String, time: float) -> Variant:
	# Find the next keyframe value in any source that affects this track
	# Implementation depends on your needs
	return null  # Replace with actual implementation

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

func seek(time: float) -> void:
	if not animation_player.has_animation(ANIMATION_NAME):
		update_animation()
	animation_player.seek(time, true)
	playback_time_changed.emit(time)

func get_current_time() -> float:
	return animation_player.current_animation_position

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
