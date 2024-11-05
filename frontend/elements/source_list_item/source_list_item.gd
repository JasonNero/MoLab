class_name SourceListItem
extends HBoxContainer

@onready var source_btn: Button = %SourceButton
@onready var duplicate_btn: Button = %DuplicateButton
@onready var remove_btn: Button = %RemoveButton

# var source: Source

func _ready() -> void:
    print("SourceListItem ready")

# func set_selected(selected: bool) -> void:
#     source_btn.button_pressed = selected
