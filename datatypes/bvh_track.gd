class_name BVHTrack
extends Track

@export_category("BVH Track")
@export_global_file("*.bvh") var file : String


func _init(name, in_point, out_point, blend_in, blend_out, file) -> void:
	super(name, in_point, out_point, blend_in, blend_out)
	self.file = file
