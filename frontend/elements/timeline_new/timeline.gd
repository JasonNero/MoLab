# timeline.gd
class_name TimelineNew
extends Control

signal source_selected(source: Source)
signal source_moved(source, time)
signal source_resized(source, edge, time)

const MAJOR_GRID_SECONDS := 1.0  # Major line every second
const MINOR_GRID_DIVISIONS := 4   # Number of minor lines between major lines
const MAJOR_GRID_COLOR := Color(1, 1, 1, 0.3)
const MINOR_GRID_COLOR := Color(1, 1, 1, 0.1)
const PLAYHEAD_COLOR := Color(1, 0, 0, 0.8)
const PLAYHEAD_WIDTH := 2.0

const MIN_PIXELS_PER_SECOND := 50.0
const MAX_PIXELS_PER_SECOND := 200.0

var pixels_per_second := 1.0
var scroll_offset := 0.0
var sources: Array[Source] = []
var source_visuals: Dictionary = {}  # Source -> TimelineSource mapping

var _scroll_container: ScrollContainer

var current_time: float = 0.0
var total_duration: float = 30.0  # Could be calculated from sources

# Drag state
var dragging_source: Source
var resize_edge: String  # "left" or "right"
var drag_start: Vector2
var initial_time: float

func _ready() -> void:
	# Get reference to scroll container
	_scroll_container = get_parent() as ScrollContainer
	if not _scroll_container:
		push_error("Timeline must be a child of ScrollContainer")

func set_sources(new_sources: Array[Source]) -> void:
	# Remove old visuals
	for visual in source_visuals.values():
		visual.queue_free()
	source_visuals.clear()

	# Create new visuals
	sources = new_sources
	for source in sources:
		var visual = TimelineSource.new()
		visual.source = source
		add_child(visual)
		source_visuals[source] = visual

	# Update total duration
	total_duration = 0
	for source in sources:
		total_duration = max(total_duration, source.out_point)

	# Ensure minimum duration for visibility
	total_duration = max(total_duration, MAJOR_GRID_SECONDS * 5)

	# Update size
	custom_minimum_size.x = _time_to_pixels(total_duration)
	queue_redraw()

func update_source(source: Source) -> void:
	if source in source_visuals:
		var visual = source_visuals[source]
		visual.update_rect(_get_source_rect(source))
		queue_redraw()

func set_selected(source: Source) -> void:
	for src in source_visuals:
		source_visuals[src].selected = (src == source)

func set_playhead_position(time: float) -> void:
	current_time = time
	ensure_time_visible(time)
	queue_redraw()

func ensure_time_visible(time: float) -> void:
	if not _scroll_container:
		return

	var x = _time_to_pixels(time)
	if x < _scroll_container.scroll_horizontal or x > _scroll_container.scroll_horizontal + _scroll_container.size.x:
		_scroll_container.scroll_horizontal = x - _scroll_container.size.x / 2

func _format_time(seconds: float) -> String:
	var minutes := int(seconds / 60)
	var remaining_seconds := fmod(seconds, 60)
	return "%02d:%05.2f" % [minutes, remaining_seconds]

func _draw_grid() -> void:
	if not _scroll_container:
		return

	var viewport_rect := get_viewport_rect()
	var content_height = max(size.y, viewport_rect.size.y)

	# Calculate visible time range
	var visible_start := _pixels_to_time(_scroll_container.scroll_horizontal)
	var visible_end := _pixels_to_time(
		_scroll_container.scroll_horizontal + _scroll_container.size.x
	)

	# Ensure we start from the previous major grid line
	var start_time = floor(visible_start / MAJOR_GRID_SECONDS) * MAJOR_GRID_SECONDS
	var end_time = ceil(visible_end / MAJOR_GRID_SECONDS) * MAJOR_GRID_SECONDS

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

func _draw_playhead() -> void:
	var x := _time_to_pixels(current_time)
	var viewport_rect := get_viewport_rect()
	var content_height = max(size.y, viewport_rect.size.y)

	# Draw playhead line
	draw_line(
		Vector2(x, 0),
		Vector2(x, content_height),
		PLAYHEAD_COLOR,
		PLAYHEAD_WIDTH
	)

	# Draw playhead triangle
	var triangle_size := 10.0
	var triangle := PackedVector2Array([
		Vector2(x - triangle_size/2, 0),
		Vector2(x + triangle_size/2, 0),
		Vector2(x, triangle_size)
	])
	draw_colored_polygon(triangle, PLAYHEAD_COLOR)

	# Draw current time
	var time_text := _format_time(current_time)
	var font := get_theme_font("normal")
	var font_size := get_theme_font_size("normal")
	var text_width := font.get_string_size(time_text, font_size).x

	# Draw time background
	var padding := 4.0
	var text_rect := Rect2(
		x - text_width/2 - padding,
		triangle_size,
		text_width + padding * 2,
		font_size + padding * 2
	)
	draw_rect(text_rect, Color(0, 0, 0, 0.8))

	# Draw time text
	draw_string(
		font,
		Vector2(x - text_width/2, triangle_size + font_size + padding),
		time_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		PLAYHEAD_COLOR
	)

func _draw() -> void:
	_draw_grid()
	_draw_playhead()

func _get_source_rect(source: Source) -> Rect2:
	var x = _time_to_pixels(source.in_point)
	var width = (source.out_point - source.in_point) * pixels_per_second
	var y = sources.find(source) * 40  # Height per track
	return Rect2(x, y, width, 35)

func _time_to_pixels(time: float) -> float:
	return time * pixels_per_second

func _pixels_to_time(pixels: float) -> float:
	return pixels / pixels_per_second

func _get_source_at_position(pos: Vector2) -> Source:
	for source in sources:
		if _get_source_rect(source).has_point(pos):
			return source
	return null

func _get_source_edge(source: Source, pos: Vector2) -> String:
	var rect = _get_source_rect(source)
	var edge_width = 5.0

	if abs(pos.x - rect.position.x) < edge_width:
		return "left"
	if abs(pos.x - (rect.position.x + rect.size.x)) < edge_width:
		return "right"
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_click(event)
			else:
				_end_drag()

	elif event is InputEventMouseMotion:
		if dragging_source:
			if resize_edge:
				_handle_edge_drag(event)
			else:
				_handle_drag(event)

func _handle_click(event: InputEvent) -> void:
	var pos = get_local_mouse_position()
	var clicked_source = _get_source_at_position(pos)

	if clicked_source:
		var edge = _get_source_edge(clicked_source, pos)
		if edge:
			_start_resize(clicked_source, edge)
		else:
			_start_drag(clicked_source)
		source_selected.emit(clicked_source)

func _start_drag(source: Source) -> void:
	dragging_source = source
	resize_edge = ""
	drag_start = get_local_mouse_position()
	initial_time = source.in_point

func _start_resize(source: Source, edge: String) -> void:
	dragging_source = source
	resize_edge = edge
	drag_start = get_local_mouse_position()
	initial_time = source.in_point if edge == "left" else source.out_point

func _handle_drag(event: InputEvent) -> void:
	var delta = get_local_mouse_position() - drag_start
	var time_delta = _pixels_to_time(delta.x)
	source_moved.emit(dragging_source, initial_time + time_delta)

func _handle_edge_drag(event: InputEvent) -> void:
	var delta = get_local_mouse_position() - drag_start
	var time_delta = _pixels_to_time(delta.x)
	source_resized.emit(dragging_source, resize_edge, initial_time + time_delta)

func _end_drag() -> void:
	dragging_source = null
	resize_edge = ""
