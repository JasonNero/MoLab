@tool

class_name TimelineItem
extends HBoxContainer

signal property_changed(source: Source, property: String, value: Variant)
signal item_selected(source: Source)

@export var source: Source

## Hack to refresh the view in the editor
@export var click_to_refresh: bool:
	set(value):
		notification(NOTIFICATION_SORT_CHILDREN)

@export var inner_panel: Panel
@export var inner_handle_left: ReferenceRect
@export var inner_handle_right: ReferenceRect
@export var outter_panel: Panel
@export var outter_handle_left: ReferenceRect
@export var outter_handle_right: ReferenceRect
@export var source_label: Label

var px_per_frame: float = 2.0

var _dragging: bool = false
var _drag_start_xpos: float
var _drag_start_value: float
var _dragging_handle: ReferenceRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	inner_handle_left.gui_input.connect(_handle_drag.bind(inner_handle_left, "blend_in"))
	inner_handle_right.gui_input.connect(_handle_drag.bind(inner_handle_right, "blend_out"))
	outter_handle_left.gui_input.connect(_handle_drag.bind(outter_handle_left, "in_point"))
	outter_handle_right.gui_input.connect(_handle_drag.bind(outter_handle_right, "out_point"))

func update():
	outter_panel.position.x = source.in_point * px_per_frame
	outter_panel.size.x = (source.out_point - source.in_point) * px_per_frame
	inner_panel.position.x = (source.in_point + source.blend_in) * px_per_frame
	inner_panel.size.x = (source.out_point - source.in_point - source.blend_in - source.blend_out) * px_per_frame
	source_label.text = source.name

	# Required to trigger scrollbars higher up the hierarchy
	custom_minimum_size = Vector2(source.out_point * px_per_frame, 28)

func set_selected(selected: bool):
	if selected:
		outter_panel.modulate = Color(0.7, 0.7, 1)
		inner_panel.modulate = Color(0.7, 0.7, 1)
	else:
		outter_panel.modulate = Color(1, 1, 1)
		inner_panel.modulate = Color(1, 1, 1)

func _notification(what: int):
	if what == NOTIFICATION_SORT_CHILDREN:
		# TODO: This could be called less often, but it's fine for now
		update()

func _handle_drag(event: InputEvent, handle: ReferenceRect, property: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_dragging_handle = handle
				# Using global to avoid parent transforms; we only care about the x delta
				_drag_start_xpos = get_global_mouse_position().x
				_drag_start_value = source.get(property)
				handle.grab_focus()
			else:
				_dragging = false

	elif event is InputEventMouseMotion and _dragging and handle == _dragging_handle:
		var delta: float = get_global_mouse_position().x - _drag_start_xpos
		var frames_delta: float = snappedf(delta / px_per_frame, 1.0)
		var new_value: float = _drag_start_value + frames_delta

		# For blend_out we want to invert the direction
		if property == "blend_out":
			new_value = _drag_start_value - frames_delta

		property_changed.emit(source, property, new_value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			item_selected.emit(source)
