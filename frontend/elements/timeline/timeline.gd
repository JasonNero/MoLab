class_name Timeline
extends VBoxContainer

signal source_selected(source: Source)
signal source_moved(source: Source, time: float)
signal source_resized(source: Source, edge: String, time: float)
signal property_changed(source: Source, property: String, value: Variant)

@export var scroll_container: ScrollContainer
@export var item_container: VBoxContainer
@export var item_scene: PackedScene

var current_time: float = 6.5
var source_items: Dictionary = {}  # Source -> Item

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
	item_container.move_child(item, index)
	item.source = source
	item.property_changed.connect(property_changed.emit)
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
	item_container.ensure_time_visible(time)
	queue_redraw()
