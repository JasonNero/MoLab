class_name Source
extends Resource

@export var name: String
@export var in_point: int
@export var out_point: int
@export var in_offset: int
@export var out_offset: int
@export var animation: Animation

func _init(_name="untitled", _in_point=0, _out_point=10, _in_offset=0, _out_offset=0) -> void:
	self.name = _name
	self.in_point = _in_point
	self.out_point = _out_point
	self.in_offset = _in_offset
	self.out_offset = _out_offset

func get_animation_frames() -> int:
	if not animation:
		return 0
	else:
		return animation.length / Globals.FPS

func is_valid() -> bool:
	return out_point > in_point

# TODO: Rework this to use/override Object.get_property_list()
func get_properties() -> Dictionary:
	return {
		"name": {"type": TYPE_STRING, "value": name, "text": "Name"},
		"in_point": {"type": TYPE_FLOAT, "value": in_point, "text": "In Point"},
		"out_point": {"type": TYPE_FLOAT, "value": out_point, "text": "Out Point"},
		"in_offset": {"type": TYPE_FLOAT, "value": in_offset, "text": "In Offset"},
		"out_offset": {"type": TYPE_FLOAT, "value": out_offset, "text": "Out Offset"},
	}

# TODO: Validate properties by overriding Object._validate_property()
func set_property(property: String, value: Variant) -> void:
	set(property, value)  # Using built-in setter

func apply(target_animation: Animation) -> Animation:
	push_warning("This source will not affect the target animation.")
	return target_animation
