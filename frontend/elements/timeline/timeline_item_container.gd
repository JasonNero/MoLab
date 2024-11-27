class_name TimelineItemContainer
extends VBoxContainer

signal playhead_moved(time: float)

const MAJOR_GRID_SECONDS := 5.0  # Major line every second
const MINOR_GRID_DIVISIONS := 5    # Number of minor lines between major lines
const MAJOR_GRID_COLOR := Color(1, 1, 1, 0.3)
const MINOR_GRID_COLOR := Color(1, 1, 1, 0.1)

var current_time: float = 6.5
var _px_per_frame: float = 2.0:
	set(value):
		_px_per_frame = value
		queue_redraw()
var scroll_container: ScrollContainer
@onready var playhead: Control = %PlayHead

var _dragging_playhead: bool = false

func _ready() -> void:
	scroll_container = get_parent()
	if not scroll_container is ScrollContainer:
		push_error("Timeline must be a child of ScrollContainer")
	playhead.gui_input.connect(_on_playhead_input)


func set_playhead_position(time: float) -> void:
	playhead.position.x = _time_to_pixels(time)

func ensure_time_visible(time: float) -> void:
	var x = _time_to_pixels(time)
	if x < scroll_container.scroll_horizontal or x > scroll_container.scroll_horizontal + scroll_container.size.x:
		scroll_container.scroll_horizontal = x - scroll_container.size.x / 2

func _on_playhead_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging_playhead = event.pressed
			print(event.as_text(), " at ", event.position)

	elif event is InputEventMouseMotion and _dragging_playhead:
		# Get event position in parent space
		var pos = playhead.position + event.position
		var time = _pixels_to_time(pos.x)
		playhead_moved.emit(time)

func _format_time(time: float) -> String:
	var minutes = floor(time / 60)
	var seconds = fmod(time, 60)
	var frames = int(time * Globals.FPS) % int(Globals.FPS)
	return "%02d:%02d.%02d" % [minutes, seconds, frames]

func _time_to_pixels(seconds: float) -> float:
	return seconds * Globals.FPS * _px_per_frame

func _pixels_to_time(pixels: int) -> float:
	return pixels / _px_per_frame / Globals.FPS

func _draw_grid() -> void:
	if not scroll_container:
		return

	var rect = get_viewport_rect()
	var content_height = rect.size.y

	# Ensure we start from the previous major grid line
	var start_time = 0
	var end_time = _pixels_to_time(rect.size.x)

	# Draw minor grid lines
	var minor_spacing := MAJOR_GRID_SECONDS / MINOR_GRID_DIVISIONS
	var current = start_time
	while current <= end_time:
		var x := _time_to_pixels(current)
		draw_line(
			Vector2(x, 0),
			Vector2(x, content_height),
			MINOR_GRID_COLOR
		)
		current += minor_spacing

	# Draw major grid lines and timestamps
	current = start_time
	while current <= end_time:
		var x := _time_to_pixels(current)

		# Draw line
		draw_line(
			Vector2(x, 0),
			Vector2(x, content_height),
			MAJOR_GRID_COLOR
		)

		# Draw timestamp
		var time_text := _format_time(current)
		var font := get_theme_font("normal")
		var font_size := get_theme_font_size("normal")
		var text_width := font.get_string_size(time_text, font_size).x

		draw_string(
			font,
			Vector2(x - text_width/2, font_size + 2),
			time_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			MAJOR_GRID_COLOR.lightened(0.5)
		)

		current += MAJOR_GRID_SECONDS

func _draw() -> void:
	_draw_grid()
