class_name SourceFile
extends Source

@export_category("File Source")
@export_global_file var filepath: String

func _init(_name="untitled", _in_point=0, _out_point=100, _in_offset=0, _out_offset=0, _file="") -> void:
	super(_name, _in_point, _out_point, _in_offset, _out_offset)
	self.filepath = _file

# Override get_properties to include base properties and TTM-specific ones
func get_properties() -> Dictionary:
	# Get base properties from parent class
	var props = super.get_properties()

	# Add SourceFile-specific properties
	props["filepath"] = {
		"type": TYPE_STRING,
		"value": filepath,
		"text": "File Path",
		"hint": PROPERTY_HINT_FILE
	}

	return props
