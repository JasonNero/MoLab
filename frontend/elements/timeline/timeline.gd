class_name Timeline
extends VBoxContainer

signal source_selected(source: Source)
signal source_moved(source, time)
signal source_resized(source, edge, time)

@export var scroll_container: ScrollContainer
@export var item_container: VBoxContainer
@export var item_scene: PackedScene

var current_time: float = 6.5
var items: Array[TimelineItem] = []

func clear() -> void:
	for child in items:
		item_container.remove_child(child)
		child.queue_free()
	items.clear()

func set_sources(sources: Array[Source]) -> void:
	clear()
	for source in sources:
		var item = item_scene.instantiate()
		item.source = source
		item_container.add_child(item)
		items.append(item)

func update_source(source: Source) -> void:
	for child in items:
		if child.source == source:
			child.update()
			break

func set_selected(source: Source) -> void:
	for child in items:
		child.set_selected(child.source == source)

func set_playhead_position(time: float) -> void:
	current_time = time
	item_container.ensure_time_visible(time)
	queue_redraw()

# Ensures the playhead is visible on the timeline and scrolls if necessary
