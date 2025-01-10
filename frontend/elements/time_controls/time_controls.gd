class_name TimeControls
extends HBoxContainer

signal play_pause_pressed(should_play: bool)
signal seek_requested(time: float)

@export var seek_start_btn: Button
@export var step_backwards_btn: Button
@export var play_pause_btn: Button
@export var step_forwards_btn: Button
@export var seek_end_btn: Button

@export var frame_spinbox: SpinBox
@export var time_spinbox: SpinBox

var pause_icon: CompressedTexture2D = preload("res://res/icons/Pause.png")
var play_icon: CompressedTexture2D = preload("res://res/icons/Play.png")

var current_frame: int = 0
var is_playing: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Forwards signals
	play_pause_btn.pressed.connect(switch_play_pause)
	frame_spinbox.value_changed.connect(on_frame_changed)
	seek_start_btn.pressed.connect(on_seek_start)
	step_backwards_btn.pressed.connect(on_step_backwards)
	step_forwards_btn.pressed.connect(on_step_forwards)
	seek_end_btn.pressed.connect(on_seek_end)

func update_time(new_time: float) -> void:
	time_spinbox.value = new_time
	current_frame = int(new_time * Globals.FPS)
	frame_spinbox.set_value_no_signal(current_frame)

func update_play_state(should_play: bool) -> void:
	is_playing = should_play
	if is_playing:
		play_pause_btn.icon = pause_icon
	else:
		play_pause_btn.icon = play_icon

func switch_play_pause() -> void:
	play_pause_pressed.emit(not is_playing)

func on_frame_changed(new_frame: int) -> void:
	seek_requested.emit(float(new_frame) / Globals.FPS)

func on_seek_start() -> void:
	seek_requested.emit(0.0)

func on_step_backwards() -> void:
	seek_requested.emit(float(current_frame - 1) / Globals.FPS)

func on_step_forwards() -> void:
	seek_requested.emit(float(current_frame + 1) / Globals.FPS)

func on_seek_end() -> void:
	# TODO: Don't know the length of the composition here
	seek_requested.emit(-1.0)
