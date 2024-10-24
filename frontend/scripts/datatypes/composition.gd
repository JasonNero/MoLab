class_name Composition
extends Resource

@export var sources: Array[Source] = []

func _to_string() -> String:
    var string = "<Composition#{}>\n".format([get_instance_id()], "{}")
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
