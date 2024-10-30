class_name SourceTween
extends Source

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Tween Source")
@export var modeltype: MODELTYPE = MODELTYPE.DEFAULT

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0, _modeltype=MODELTYPE.DEFAULT) -> void:
	super(_name, _in_point, _out_point, _blend_in, _blend_out)
	self.modeltype = _modeltype

func _to_string() -> String:
	return "<SourceTween#{} ({}, {}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out, modeltype], "{}")
