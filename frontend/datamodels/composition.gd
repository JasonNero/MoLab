class_name Composition
extends Resource

@export var name: String = "Untitled"
@export var sources: Array[Source] = []:
	set(new_value):
		if sources != new_value:
			sources = new_value
			emit_changed()

func _init() -> void:
	changed.connect(func (): print("Composition {0} changed".format([name])))

func _to_string() -> String:
	var string = "<Composition#{}#{}>\n".format([get_instance_id(), name], "{}")
	for source in sources:
		string += "    " + source.to_string() + "\n"
	return string

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
	emit_changed()

func insert_source(source: Source, index: int = 0) -> void:
	sources.insert(index, source)
	emit_changed()

func remove_source_at(index: int) -> void:
	sources.pop_at(index)
	emit_changed()

func remove_source(source: Source) -> void:
	sources.erase(source)
	emit_changed()

