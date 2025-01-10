class_name AnimationComposer
extends Node

signal playback_time_changed(time: float)

var composition: Composition
var animation_player: AnimationPlayer
var animation_lib: AnimationLibrary
var current_animation: Animation = Animation.new()

# Configuration
const ANIMATION_LIBRARY_NAME := "composer"
const ANIMATION_NAME := ANIMATION_LIBRARY_NAME + "/" + "latest"

var disable_update := false

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

func initialize(p_composition: Composition, viewport3d: Viewport3D) -> void:
	composition = p_composition
	composition.source_modified.connect(_on_composition_source_modified)
	composition.source_added.connect(_on_composition_source_added)
	composition.source_removed.connect(_on_composition_source_removed)

	animation_lib = AnimationLibrary.new()
	animation_lib.resource_name = ANIMATION_LIBRARY_NAME

	viewport3d.animation_player_changed.connect(_configure_animation_player)
	_configure_animation_player(viewport3d.current_player)

func _configure_animation_player(p_animation_player: AnimationPlayer) -> void:
	animation_player = p_animation_player
	animation_player.clear_queue()
	animation_player.add_animation_library(ANIMATION_LIBRARY_NAME, animation_lib)
	update_animation()

func update_animation() -> void:
	if disable_update:
		return
	if current_animation:
		current_animation.clear()
	if composition.sources.size() == 0:
		return

	animation_player.pause()
	current_animation.resource_name = "latest"
	current_animation.loop = true
	current_animation.length = float(composition.get_frame_range()[1]) / Globals.FPS

	# Merge all source animations from bottom to top
	for i in range(composition.sources.size() - 1, -1, -1):
		var source := composition.sources[i]
		current_animation = source.apply(current_animation)

	if Globals.DEBUG:
		ResourceSaver.save(current_animation, "res://tmp/debug_latest_anim.tres")

	# Update animation player
	if animation_player.has_animation(ANIMATION_NAME):
		animation_lib.remove_animation(ANIMATION_NAME.split("/")[1])
	animation_lib.add_animation(ANIMATION_NAME.split("/")[1], current_animation)
	animation_player.set_assigned_animation(ANIMATION_NAME)

	# Ensure we're at a valid position
	var current_time := get_current_time()
	if current_time > current_animation.length:
		seek(current_animation.length)

# Playback Control
func play() -> void:
	if not animation_player.has_animation(ANIMATION_NAME):
		update_animation()
	else:
		animation_player.play(ANIMATION_NAME)

func pause() -> void:
	animation_player.pause()

func stop() -> void:
	animation_player.stop()

func seek(time: float) -> void:
	if not animation_player.has_animation(ANIMATION_NAME):
		update_animation()
	else:
		# TODO: Figure out when and why the AnimationPlayer/Mixer is crashing Godot ...
		# 		Check if the issue persists in newer versions of Godot
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
func _on_composition_source_modified(_source: Source) -> void:
	update_animation()

func _on_composition_source_added(_index: int, _source: Source) -> void:
	update_animation()

func _on_composition_source_removed(_source: Source) -> void:
	update_animation()

# Frame Update
func _process(_delta: float) -> void:
	if not animation_player:
		return
	if animation_player.is_playing():
		playback_time_changed.emit(get_current_time())
