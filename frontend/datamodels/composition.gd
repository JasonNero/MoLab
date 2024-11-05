class_name Composition
extends Resource

signal selection_changed(source: Source)
signal source_added(source: Source)
signal source_removed(source: Source)
signal source_modified(source: Source)

@export var name: String = "Untitled"
@export var sources: Array[Source] = []

var selected_source: Source

func get_time_range() -> Array:
	var min_time = 0
	var max_time = 0
	for source in sources:
		min_time = min(min_time, source.in_point)
		max_time = max(max_time, source.out_point)
	return [min_time, max_time]

func clear() -> void:
	name = "Untitled"
	sources.clear()

func insert_source(source: Source, index: int = 0) -> void:
	sources.insert(index, source)
	source_added.emit(source)

func remove_source(source: Source) -> void:
	sources.erase(source)
	source_removed.emit(source)

func set_selected_source(source: Source) -> void:
	if selected_source != source:
		selected_source = source
		selection_changed.emit(source)

func get_selected_source() -> Source:
	return selected_source
