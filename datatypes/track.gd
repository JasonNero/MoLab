class_name Track
extends Resource

@export var name : String

@export var in_point : int
@export var out_point : int
@export var blend_in : int
@export var blend_out : int


#func _init(name, in_point, out_point, blend_in, blend_out) -> void:
	#self.name = name
	#self.in_point = in_point
	#self.out_point = out_point
	#self.blend_in = blend_in
	#self.blend_out = blend_out
