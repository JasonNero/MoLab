class_name SourceTTM
extends Source

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Text To Motion Source")
@export_placeholder("A person ...") var text: String
@export var modeltype: MODELTYPE = MODELTYPE.DEFAULT

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0, _text="", _modeltype=MODELTYPE.DEFAULT) -> void:
	super(_name, _in_point, _out_point, _blend_in, _blend_out)
	self.text = _text
	self.modeltype = _modeltype

func _to_string() -> String:
	return "<SourceTTM#{} ({}, {}, {}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out, text, modeltype], "{}")
