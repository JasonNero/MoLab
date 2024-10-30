extends HBoxContainer

@export var seek_start_btn: Button
@export var step_backwards_btn: Button
@export var play_pause_btn: Button
@export var step_forwards_btn: Button
@export var seek_end_btn: Button

@export var frame_spinbox: SpinBox

signal seek_start_pressed()
signal step_backwards_pressed()
signal play_pause_pressed()
signal step_forwards_pressed()
signal seek_end_pressed()

var pause_icon: CompressedTexture2D = preload("res://res/icons/Pause.png")
var play_icon: CompressedTexture2D = preload("res://res/icons/PlayStart.png")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Forwards signals
	seek_start_btn.pressed.connect(seek_start_pressed.emit)
	step_backwards_btn.pressed.connect(step_backwards_pressed.emit)
	play_pause_btn.pressed.connect(play_pause_pressed.emit)
	step_forwards_btn.pressed.connect(step_forwards_pressed.emit)
	seek_end_btn.pressed.connect(seek_end_pressed.emit)

func set_frame(frame: int) -> void:
	frame_spinbox.value = frame

func switch_play_pause(is_playing: bool) -> void:
	if is_playing:
		play_pause_btn.icon = pause_icon
	else:
		play_pause_btn.icon = play_icon
