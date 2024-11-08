class_name Viewport3D
extends SubViewportContainer

enum CHARACTER {
	SMPL_FEMALE = 0,
	SMPL_MALE = 1,
	LAFAN = 2,
	MIXAMO_AKAI = 3,
	MIXAMO_MARKERMAN = 4,
}

signal character_changed()

@export var character_type: CHARACTER = CHARACTER.LAFAN:
	set(value):
		character_type = value
		character_changed.emit()

@export var smpl_f: PackedScene
@export var smpl_m: PackedScene
@export var lafan: PackedScene
@export var mixamo_akai: PackedScene
@export var mixamo_markerman: PackedScene

@export var anim_player: AnimationPlayer

var current_char: Node
var current_skel: Skeleton3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	character_changed.connect(_update_character)
	_update_character()


func _update_character() -> void:
	if current_char != null:
		%World.remove_child(current_char)

	match character_type:
		CHARACTER.SMPL_FEMALE:
			current_char = smpl_f.instantiate()
		CHARACTER.SMPL_MALE:
			current_char = smpl_m.instantiate()
		CHARACTER.LAFAN:
			current_char = lafan.instantiate()
		CHARACTER.MIXAMO_AKAI:
			current_char = mixamo_akai.instantiate()
		CHARACTER.MIXAMO_MARKERMAN:
			current_char = mixamo_markerman.instantiate()

	%World.add_child(current_char)
	current_skel = current_char.find_child("GeneralSkeleton", true)
	anim_player.set_root(current_skel.get_parent().get_path())


func get_animation_player() -> AnimationPlayer:
	return anim_player
