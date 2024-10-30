class_name PropertiesPanel
extends Control

@export var properties: PropertiesBox

var remap_keys := {
	"Name": "name",
	"In Point": "in_point",
	"Out Point": "out_point",
	"Blend In": "blend_in",
	"Blend Out": "blend_out",
	"BVH File": "file",
	"Text": "text",
	"Inference Model": "modeltype"
}

signal current_source_property_changed(property: String, value: Variant)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	properties.value_changed.connect(_on_value_changed)

# TODO: Do granular changes (instead of re-creating all widgets)
func view(source: Source) -> void:
	var class_string := ""
	if source is SourceBVH:
		class_string = "SourceBVH"
	elif source is SourceTTM:
		class_string = "SourceTTM"
	elif source is SourceTween:
		class_string = "SourceTween"

	properties.clear()
	properties.add_group("General Properties")
	_add_line_edit("Name", source.name)
	_add_int_edit("In Point", source.in_point)
	_add_int_edit("Out Point", source.out_point)
	_add_int_edit("Blend In", source.blend_in)
	_add_int_edit("Blend Out", source.blend_out)
	properties.end_group()

	properties.add_group("Source Specific")
	match class_string:
		"SourceBVH":
			_add_line_edit("BVH File", source.file)
		"SourceTTM":
			_add_line_edit("Text", source.text)
			properties.add_options("Inference Model", SourceTTM.MODELTYPE.keys(), source.modeltype)
		"SourceTween":
			properties.add_options("Inference Model", SourceTTM.MODELTYPE.keys(), source.modeltype)

# Like `add_string` but only triggers on submit, not on every change.
func _add_line_edit(key: StringName, value: String):
	var editor = LineEdit.new()
	editor.text = value
	properties._add_property_editor(key, editor, editor.text_submitted, properties._on_string_changed)

# Like `add_int` but allows greater values.
# TODO: Just copy/paste/modify the full PropertiesBox.gd file instead...
func _add_int_edit(key: StringName, value: int):
	var editor = SpinBox.new()
	editor.allow_greater = true
	editor.value = value
	properties._add_property_editor(key, editor, editor.value_changed, properties._on_number_changed)

func _on_value_changed(key: StringName, new_value: Variant):
	print("Value changed: {0} = {1}".format([key, new_value]))
	current_source_property_changed.emit(remap_keys[key], new_value)

