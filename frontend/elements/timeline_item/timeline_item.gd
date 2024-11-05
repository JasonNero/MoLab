@tool

class_name TimelineItem
extends HBoxContainer

@export var source: Source

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

@export var px_per_frame: float = 2.0

var handle_dragging: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	inner_handle_left.gui_input.connect(test)

func update():
	outter_panel.position.x = source.in_point * px_per_frame
	outter_panel.size.x = (source.out_point - source.in_point) * px_per_frame

	inner_panel.position.x = (source.in_point + source.blend_in) * px_per_frame
	inner_panel.size.x = (source.out_point - source.in_point - source.blend_in - source.blend_out) * px_per_frame

	source_label.text = source.name

	# Required to actually get scrollbars up the hierarchy
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

func test(event: InputEvent):
	if event is InputEventMouseButton:
		print("test: ", event)
		print("TODO: Implement handle dragging/resizing")
