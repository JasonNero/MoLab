class_name MainEditor
extends Control

# Scene references
@export var source_view: SourceView
@export var properties_panel: PropertiesPanel
@export var time_controls: TimeControls
@export var viewport_3d: Viewport3D
@export var composition_controller: CompositionController
@export var animation_composer: AnimationComposer

# Resource reference
@export var composition: Composition

func _ready() -> void:
	if composition == null:
		composition = load_or_create_composition()

	# Initialize controllers
	composition_controller.initialize(
		composition,
		source_view,
		properties_panel,
		time_controls,
		animation_composer
	)

	animation_composer.initialize(
		composition,
		viewport_3d.get_animation_player()
	)

func load_or_create_composition() -> Composition:
	var comp = ResourceLoader.load("user://current_composition.tres")
	if comp == null:
		comp = Composition.new()
	return comp

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_composition()
		get_tree().quit()

func save_composition() -> void:
	if composition:
		ResourceSaver.save(composition, "user://current_composition.tres")
