extends PanelContainer

@export_category("Clip Properties")
@export var in_frame: int = 10
@export var out_frame: int = 50
@export var blend_in_frames: int = 2
@export var blend_out_frames: int = 2
@export_placeholder("a person  ...") var text: String

# Called when the node enters the scene tree for the first time.
func _ready():
	$MarginContainer/HBoxContainer/LineEdit.text = text
	#$MarginContainer.position.x = in_frame * 10
	#$MarginContainer.size.x = out_frame * 10
	set_position(Vector2(in_frame * 10, position.y))
	set_size(Vector2((out_frame - in_frame) * 10, size.y))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


## SIGNALS ##

func _on_line_edit_text_changed(new_text):
	text = new_text


func _on_generate_button_pressed():
	$MarginContainer/HBoxContainer/LineEdit.editable = false
	$MarginContainer/HBoxContainer/GenerateButton.text = "Generating ..."
	$MarginContainer/HBoxContainer/GenerateButton.disabled = true
