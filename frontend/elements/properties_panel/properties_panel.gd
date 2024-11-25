# properties_panel.gd
class_name PropertiesPanel
extends Control

signal property_changed(source: Source, property: String, value: Variant)

@onready var properties_container = %PropertiesContainer
var composition: Composition
var current_source: Source
var property_controls: Dictionary = {} # Property name -> Control

func setup(p_composition: Composition) -> void:
	composition = p_composition
	composition.source_modified.connect(_on_composition_source_modified)
	composition.selection_changed.connect(view_source)

func clear() -> void:
	for control in property_controls.values():
		control.queue_free()
	property_controls.clear()

func view_source(source: Source) -> void:
	if source == current_source:
		var properties = source.get_properties()
		# Update in-place
		for property_name in properties:
			var property = properties[property_name]
			set_property_view_value(property_name, property.value)
	elif source:
		# Clear and re-create
		clear()
		current_source = source
		var properties = source.get_properties()
		for property_name in properties:
			var property = properties[property_name]
			var control = _create_property_control(
				property_name,
				property
			)
			property_controls[property_name] = control
			properties_container.add_child(control)
	else:
		clear()
		current_source = null

# Handle different control types when updating property values
func set_property_view_value(property: String, value: Variant) -> void:
	var control = property_controls.get(property)
	if control:
		var input = control.get_children()[-1]  # Get the input control
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

func _create_property_control(_name: String, property_info: Dictionary) -> Control:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = property_info.get("text", _name)
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
					_on_property_changed.bind(_name)
				)
			else:
				input = LineEdit.new()
				input.text = property_info.value
				input.text_submitted.connect(
					_on_property_changed.bind(_name)
				)
		TYPE_INT:
			if property_info.get("hint") == PROPERTY_HINT_ENUM:
				input = OptionButton.new()
				var options = property_info.get("hint_string", "").split(",")
				for i in options.size():
					input.add_item(options[i], i)
				input.selected = property_info.value
				input.item_selected.connect(
					_on_property_changed.bind(_name)
				)
			else:
				input = SpinBox.new()
				input.allow_greater = true
				input.allow_lesser = true
				input.value = property_info.value
				input.value_changed.connect(
					_on_property_changed.bind(_name)
				)
		TYPE_FLOAT:
			input = SpinBox.new()
			input.step = 0.1  # Smaller steps for float values
			input.allow_greater = true
			input.allow_lesser = true
			input.value = property_info.value
			input.value_changed.connect(
				_on_property_changed.bind(_name)
			)
		TYPE_BOOL:
			container.remove_child(label)
			input = CheckButton.new()
			input.text = property_info.get("text", _name)
			input.button_pressed = property_info.value
			input.toggled.connect(
				_on_property_changed.bind(_name)
			)
		TYPE_CALLABLE:
			container.remove_child(label)
			input = Button.new()
			input.text = property_info.text
			input.pressed.connect(
				_on_property_changed.bind(true, _name)
			)
		_:
			push_error("Unsupported property type: ", property_info.type)
			return null
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(input)
	return container

func _on_property_changed(value: Variant, property: String) -> void:
	property_changed.emit(current_source, property, value)

func _on_composition_source_modified(source: Source) -> void:
	if source == composition.selected_source:
		view_source(source)
