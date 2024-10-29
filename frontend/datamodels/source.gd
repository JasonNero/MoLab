class_name Source
extends Resource

@export var name: String:
	set(new_value):
		if name != new_value:
			name = new_value
			emit_changed()

@export var in_point: int:
	set(new_value):
		if in_point != new_value:
			in_point = new_value
			emit_changed()

@export var out_point: int:
	set(new_value):
		if out_point != new_value:
			out_point = new_value
			emit_changed()

@export var blend_in: int:
	set(new_value):
		if blend_in != new_value:
			blend_in = new_value
			emit_changed()

@export var blend_out: int:
	set(new_value):
		if blend_out != new_value:
			blend_out = new_value
			emit_changed()

@export var animation: Animation:
	set(new_value):
		if animation != new_value:
			animation = new_value
			emit_changed()

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0) -> void:
	self.name = _name
	self.in_point = _in_point
	self.out_point = _out_point
	self.blend_in = _blend_in
	self.blend_out = _blend_out
	changed.connect(func(): print("Source {0} changed".format([name])))

func _to_string() -> String:
	return "<Track#{} ({}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out], "{}")

