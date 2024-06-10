class_name TweenTrack
extends Track

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Tween Track")
@export var model: MODELTYPE = MODELTYPE.DEFAULT


func _init(name, in_point, out_point, blend_in, blend_out, model) -> void:
	self.name = name
	self.in_point = in_point
	self.out_point = out_point
	self.blend_in = blend_in
	self.blend_out = blend_out
	self.model = model
