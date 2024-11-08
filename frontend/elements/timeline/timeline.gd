class_name Timeline
extends VBoxContainer

signal source_selected(source: Source)
signal source_moved(source: Source, in_point: int)
signal property_changed(source: Source, property: String, value: Variant)

@export var item_container: TimelineItemContainer
@export var item_scene: PackedScene

var current_time: float = 6.5
var source_items: Dictionary = {}  # Source -> Item
var px_per_frame: float = 2.0:
	set(value):
		# TODO: Clean this up by combining Timeline and TimelineItemContainer?
		px_per_frame = value
		item_container._px_per_frame = value
		for source in source_items:
			source_items[source]._px_per_frame = value

func setup(sources: Array[Source]) -> void:
	clear()
	for source in sources:
		add_source(source)

func clear() -> void:
	for source in source_items:
		item_container.remove_child(source_items[source])
		source_items[source].queue_free()
	source_items.clear()

func update_source(source: Source) -> void:
	var item: TimelineItem = source_items[source]
	item.update()

func insert_source(index: int, source: Source) -> void:
	var item: TimelineItem = item_scene.instantiate()
	item_container.add_child(item)
	if index > -1:
		# Adding 1 to account for the playhead
		index += 1
	item_container.move_child(item, index)
	item.source = source
	item.property_changed.connect(property_changed.emit)
	item.item_moved.connect(source_moved.emit)
	item.item_selected.connect(source_selected.emit)
	source_items[source] = item

func add_source(source: Source) -> void:
	# Insert source at the end
	insert_source(-1, source)

func remove_source(source: Source) -> void:
	item_container.remove_child(source_items[source])
	source_items[source].queue_free()
	source_items.erase(source)

func set_selected(selected_source: Source) -> void:
	for source in source_items:
		var item: TimelineItem = source_items[source]
		item.set_selected(source == selected_source)

func set_playhead_position(time: float) -> void:
	current_time = time
	item_container.set_playhead_position(time)
	item_container.ensure_time_visible(time)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.shift_pressed:
			# NOTE: MacOS automatically translates [shift+wheel up/down] to [wheel left/right]
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
				px_per_frame *= 1.1
			elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
				px_per_frame /= 1.1
