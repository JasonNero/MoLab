class_name SourceTTM
extends Source

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Text To Motion Source")
@export_placeholder("A person ...") var text: String
@export var modeltype: MODELTYPE = MODELTYPE.DEFAULT

var is_dirty: bool = false

func _init(_name="untitled", _in_point=0, _out_point=10, _in_offset=0, _out_offset=0, _text="", _modeltype=MODELTYPE.DEFAULT) -> void:
	super(_name, _in_point, _out_point, _in_offset, _out_offset)
	self.text = _text
	self.modeltype = _modeltype

func process_data() -> void:
	# External processing logic here
	print("Processing...")
	is_dirty = false

func mark_dirty() -> void:
	is_dirty = true

func is_processed() -> bool:
	return not is_dirty

# Override get_properties to include base properties and TTM-specific ones
func get_properties() -> Dictionary:
	# Get base properties from parent class
	var props = super.get_properties()

	# Add TTM-specific properties
	props["text"] = {
		"type": TYPE_STRING,
		"value": text,
	}

	props["modeltype"] = {
		"type": TYPE_INT,  # Enums are internally stored as ints
		"value": modeltype,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Default,Legacy,Experimental"  # Comma-separated enum values
	}

	return props

# Override set_property to handle the new properties
func set_property(property: String, value: Variant) -> void:
	match property:
		"name":
			# Handle properties that do not require re-processing
			set(property, value)
		_:
			# Handle properties that require re-processing
			set(property, value)
			mark_dirty()
