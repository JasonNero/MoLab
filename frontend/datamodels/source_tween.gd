class_name SourceTween
extends Source

enum MODELTYPE {DEFAULT, LEGACY, EXPERIMENTAL}

@export_category("Tween Source")
@export var modeltype: MODELTYPE = MODELTYPE.DEFAULT

var is_dirty: bool = false

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0, _modeltype=MODELTYPE.DEFAULT) -> void:
	super(_name, _in_point, _out_point, _blend_in, _blend_out)
	self.modeltype = _modeltype

func _to_string() -> String:
	return "<SourceTween#{} ({}, {}, {}, {}, {}, {})>".format(
		[get_instance_id(), name, in_point, out_point, blend_in, blend_out, modeltype], "{}")


func process_data() -> void:
	# External processing logic here
	print("Processing...")
	is_dirty = false

func mark_dirty() -> void:
	is_dirty = true

func is_processed() -> bool:
	return not is_dirty

# Override get_properties to include base properties and Tween-specific ones
func get_properties() -> Dictionary:
	# Get base properties from parent class
	var props = super.get_properties()

	# Add Tween-specific properties
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
