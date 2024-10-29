class_name Timeline
extends VBoxContainer

@export var item_container: VBoxContainer
@export var item_scene: PackedScene


func clear() -> void:
	for child in item_container.get_children():
		item_container.remove_child(child)
		child.queue_free()

func update(sources: Array[Source]):
	clear()
	for source in sources:
		var item = item_scene.instantiate()
		item.source = source
		item_container.add_child(item)

# This clashes with the scroll container
# func _gui_input(event: InputEvent):
# 	if event is InputEventMouseButton:
# 		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
# 			for child in item_container.get_children():
# 				child.px_per_frame *= 0.9

# 		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
# 			for child in item_container.get_children():
# 				child.px_per_frame *= 1.1
