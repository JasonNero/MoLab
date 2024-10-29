class_name PropertiesPanel
extends Control

@export var properties: PropertiesBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func update(source: Source) -> void:

	var class_string := ""
	if source is SourceBVH:
		class_string = "SourceBVH"
	elif source is SourceTTM:
		class_string = "SourceTTM"
	elif source is SourceTween:
		class_string = "SourceTween"


	properties.clear()
	properties.add_group(class_string)
	properties.add_string("Name", source.name)
	properties.add_int("In Point", source.in_point)
	properties.add_int("Out Point", source.out_point)
	properties.add_int("Blend In", source.blend_in)
	properties.add_int("Blend Out", source.blend_out)

	match class_string:
		"SourceBVH":
			properties.add_string("BVH File", source.file)
		"SourceTTM":
			properties.add_string("Text", source.text)
			properties.add_options("Inference Model", SourceTTM.MODELTYPE.keys(), source.model)
		"SourceTween":
			properties.add_options("Inference Model", SourceTTM.MODELTYPE.keys(), source.model)
