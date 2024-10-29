@tool

class_name TimelineItem
extends HBoxContainer

@export var source: Source

@export var click_to_refresh: bool:
	set(value):
		notification(NOTIFICATION_SORT_CHILDREN)

@export var inner_panel: Panel
@export var outter_panel: Panel
@export var source_label: Label

@export var px_per_frame: float = 4.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _notification(what: int):
	if what == NOTIFICATION_SORT_CHILDREN:
		# TODO: This could be called less often, but it's fine for now

		outter_panel.position.x = source.in_point * px_per_frame
		outter_panel.size.x = (source.out_point - source.in_point) * px_per_frame

		inner_panel.position.x = (source.in_point + source.blend_in) * px_per_frame
		inner_panel.size.x = (source.out_point - source.in_point - source.blend_in - source.blend_out) * px_per_frame

		source_label.text = source.name

		# Required to actually get scrollbars up the hierarchy
		custom_minimum_size = Vector2(source.out_point * px_per_frame, 28)
