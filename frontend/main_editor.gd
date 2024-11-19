class_name MainEditor
extends Control

# Scene references
@export var source_view: SourceView
@export var properties_panel: PropertiesPanel
@export var time_controls: TimeControls
@export var viewport_3d: Viewport3D
@export var composition_controller: CompositionController
@export var animation_composer: AnimationComposer
@export var import_bvh_dialog: ImportDialog

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

	get_window().close_requested.connect(_autosave)
	%AutosaveTimer.timeout.connect(_autosave)

func load_or_create_composition() -> Composition:
	var comp = ResourceLoader.load("user://current_composition.tres") as Composition
	if comp == null:
		print("Last composition not found, creating new composition...")
		comp = Composition.new()
	return comp

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_composition()
		get_tree().quit()

func save_composition(filename: String = "current_composition.tres") -> void:
	if composition:
		ResourceSaver.save(composition, "user://" + filename)

# Save on window close
func _autosave() -> void:
	print("Autosaving...")
	save_composition("autosave.tres")
