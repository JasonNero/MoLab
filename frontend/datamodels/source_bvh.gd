class_name SourceBVH
extends Source

@export_category("BVH Source")
@export_global_file("*.bvh") var file: String

func _init(_name="untitled", _in_point=0, _out_point=10, _blend_in=0, _blend_out=0, _file="") -> void:
	super(_name, _in_point, _out_point, _blend_in, _blend_out)
	self.file = _file

# Override get_properties to include base properties and TTM-specific ones
func get_properties() -> Dictionary:
	# Get base properties from parent class
	var props = super.get_properties()

	# Add BVH-specific properties
	props["file"] = {
		"type": TYPE_STRING,
		"value": file,
		"hint": PROPERTY_HINT_FILE
	}

	return props

# Override set_property to handle the new properties
func set_property(property: String, value: Variant) -> void:
	set(property, value)
