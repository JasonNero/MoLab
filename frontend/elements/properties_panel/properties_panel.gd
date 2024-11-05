# properties_panel.gd
class_name PropertiesPanel
extends Control

signal property_changed(source: Source, property: String, value: Variant)

var current_source: Source
var property_controls: Dictionary = {}

func setup_for_source(source: Source) -> void:
	clear()
	current_source = source

	if not source:
		return

	var properties = source.get_properties()
	for property_name in properties:
		var property = properties[property_name]
		var control = _create_property_control(
			property_name,
			property
		)
		property_controls[property_name] = control
		%PropertiesContainer.add_child(control)

func clear() -> void:
	current_source = null
	for control in property_controls.values():
		control.queue_free()
	property_controls.clear()

func _create_property_control(name: String, property_info: Dictionary) -> Control:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)

	var input: Control
	match property_info.type:
		TYPE_STRING:
			if property_info.get("hint") == PROPERTY_HINT_MULTILINE_TEXT:
				input = TextEdit.new()
				input.text = property_info.value
				input.custom_minimum_size.y = 100  # Give some vertical space
				input.text_changed.connect(
					_on_property_changed.bind(name)
				)
			else:
				input = LineEdit.new()
				input.text = property_info.value
				input.text_changed.connect(
					_on_property_changed.bind(name)
				)
		TYPE_INT:
			if property_info.get("hint") == PROPERTY_HINT_ENUM:
				input = OptionButton.new()
				var options = property_info.get("hint_string", "").split(",")
				for i in options.size():
					input.add_item(options[i], i)
				input.selected = property_info.value
				input.item_selected.connect(
					_on_property_changed.bind(name)
				)
			else:
				input = SpinBox.new()
				input.allow_greater = true
				input.value = property_info.value
				input.value_changed.connect(
					_on_property_changed.bind(name)
				)
		TYPE_FLOAT:
			input = SpinBox.new()
			input.step = 0.1  # Smaller steps for float values
			input.allow_greater = true
			input.value = property_info.value
			input.value_changed.connect(
				_on_property_changed.bind(name)
			)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(input)
	return container

# Handle different control types when updating property values
func update_property(property: String, value: Variant) -> void:
	var control = property_controls.get(property)
	if control:
		var input = control.get_child(1)  # Get the input control
		input.set_block_signals(true)

		# Handle different control types
		if input is OptionButton:
			input.selected = value
		elif input is TextEdit:
			input.text = value
		elif input is LineEdit:
			input.text = value
		elif input is SpinBox:
			input.value = value

		input.set_block_signals(false)

func _on_property_changed(value: Variant, property: String) -> void:
	if current_source:
		property_changed.emit(current_source, property, value)
