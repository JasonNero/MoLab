class_name SourceBVH
extends Source

@export_category("BVH Source")
@export_global_file("*.bvh") var file: String

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0, _file="") -> void:
	super(_name, _in_point, _out_point, _blend_in, _blend_out)
	self.file = _file

func _to_string() -> String:
	return "<SourceBVH#{} ({}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out, file], "{}")

static func from_file(_file: String) -> SourceBVH:
	var source = SourceBVH.new()
	return source
