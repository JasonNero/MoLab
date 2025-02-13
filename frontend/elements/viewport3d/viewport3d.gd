class_name Viewport3D
extends SubViewportContainer

signal character_changed()
signal animation_player_changed(player: AnimationPlayer)

@export var characters: Dictionary
@export var character_type: String:
	set(value):
		character_type = value
		character_changed.emit()

var current_player: AnimationPlayer
var current_char: Node
var current_skel: Skeleton3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	character_changed.connect(_update_character)
	_update_character()

func _update_character() -> void:
	if current_char != null:
		%World.remove_child(current_char)

	var current_char_scene = characters.get(character_type)
	if current_char_scene == null:
		return

	current_char = current_char_scene.instantiate()

	%World.add_child(current_char)
	current_char.set_owner(%World)
	current_skel = current_char.find_child("GeneralSkeleton")
	current_player = current_char.find_child("AnimationPlayer")
	if current_player == null:
		current_player = AnimationPlayer.new()
		current_skel.get_parent().add_child(current_player)
	current_player.remove_animation_library("")  # Get rid of the default library
	animation_player_changed.emit(current_player)
