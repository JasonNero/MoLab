class_name Source
extends Resource

@export var name: String

@export var in_point: int
@export var out_point: int
@export var blend_in: int
@export var blend_out: int

@export var animation: Animation

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0) -> void:
	self.name = _name
	self.in_point = _in_point
	self.out_point = _out_point
	self.blend_in = _blend_in
	self.blend_out = _blend_out

func _to_string() -> String:
	return "<Track#{} ({}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out], "{}")
