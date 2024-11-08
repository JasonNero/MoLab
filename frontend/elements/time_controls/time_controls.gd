class_name TimeControls
extends HBoxContainer

signal play_pause_pressed(should_play: bool)
signal time_changed(new_time: int)
signal seek_requested(time: int)

@export var seek_start_btn: Button
@export var step_backwards_btn: Button
@export var play_pause_btn: Button
@export var step_forwards_btn: Button
@export var seek_end_btn: Button

@export var frame_spinbox: SpinBox

var pause_icon: CompressedTexture2D = preload("res://res/icons/Pause.png")
var play_icon: CompressedTexture2D = preload("res://res/icons/PlayStart.png")

var current_frame: int = 0
var is_playing: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Forwards signals
	play_pause_btn.pressed.connect(switch_play_pause)

func update_time(new_time: float) -> void:
	current_frame = int(new_time * Globals.FPS)
	frame_spinbox.value = current_frame

func update_play_state(should_play: bool) -> void:
	is_playing = should_play
	if is_playing:
		play_pause_btn.icon = pause_icon
	else:
		play_pause_btn.icon = play_icon

func switch_play_pause() -> void:
	play_pause_pressed.emit(not is_playing)
