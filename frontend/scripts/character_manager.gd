extends Node3D

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

@onready var smpl_f: Node = preload("res://res/models/basicModel_f_re-export.fbx").instantiate()
@onready var smpl_m: Node = preload("res://res/models/basicModel_m_re-export.fbx").instantiate()
@onready var lafan: Node = preload("res://res/models/lafan_skeleton.fbx").instantiate()
@onready var mixamo_akai: Node = preload("res://res/models/Longbow Locomotion Pack/akai_e_espiritu.fbx").instantiate()
@onready var mixamo_markerman: Node = preload("res://res/models/Passive_Marker_Man.glb").instantiate()

var current_char: Node
var current_skel: Skeleton3D
@onready var anim_player: AnimationPlayer = %AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	character_changed.connect(_update_character)
	_update_character()


func _update_character() -> void:
	if current_char != null:
		remove_child(current_char)

	match character_type:
		CHARACTER.SMPL_FEMALE:
			current_char = smpl_f
		CHARACTER.SMPL_MALE:
			current_char = smpl_m
		CHARACTER.LAFAN:
			current_char = lafan
		CHARACTER.MIXAMO_AKAI:
			current_char = mixamo_akai
		CHARACTER.MIXAMO_MARKERMAN:
			current_char = mixamo_markerman

	add_child(current_char)
	current_skel = current_char.find_child("GeneralSkeleton", true)
	anim_player.set_root(current_skel.get_parent().get_path())
	anim_player.play("example_inference_animation")

	print("Current Char: ", get_current_char())
	print("Current Skeleton: ", get_current_skeleton())


func get_current_char() -> Node:
	return current_char


func get_current_skeleton() -> Skeleton3D:
	return current_char.find_child("GeneralSkeleton", true)
