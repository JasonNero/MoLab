class_name TweenTrack
extends Track

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Tween Track")
@export var model: MODELTYPE = MODELTYPE.DEFAULT

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0, _model=MODELTYPE.DEFAULT) -> void:
	super(_name, _in_point, _out_point, _blend_in, _blend_out)
	self.model = _model

func _to_string() -> String:
	return "<TweenTrack#{} ({}, {}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out, model], "{}")
