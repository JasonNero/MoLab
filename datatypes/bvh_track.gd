class_name BVHTrack
extends Track

@export_category("BVH Track")
@export_global_file("*.bvh") var file : String


func _init(name, in_point, out_point, blend_in, blend_out, file) -> void:
	self.name = name
	self.in_point = in_point
	self.out_point = out_point
	self.blend_in = blend_in
	self.blend_out = blend_out
	self.file = file
