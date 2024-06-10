class_name TTMTrack
extends Track

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Text To Motion")
@export_placeholder("A person ...") var text : String
@export var model: MODELTYPE = MODELTYPE.DEFAULT


func _init(name, in_point, out_point, blend_in, blend_out, text, model) -> void:
	super(name, in_point, out_point, blend_in, blend_out)
	self.model = model
