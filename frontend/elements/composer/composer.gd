class_name Composer
extends Node

var _composition: Composition
var _animation_library: AnimationLibrary
var _selected_source_idx: int = 0

@export var backend: BackendWebSocket
@export var dcc: DCCWebSocket
@export var animation_player: AnimationPlayer

@export var properties_panel: PropertiesPanel
@export var source_view: SourceView
@export var timeline: Timeline
@export var world: World

func _ready() -> void:
	_animation_library = AnimationLibrary.new()
	_composition = _get_placeholder_comp()

	call_deferred("connect_character")
	update()

func _get_placeholder_comp() -> Composition:
	var _comp = Composition.new()
	_comp.sources.append(SourceTween.new("Transition", 70, 100, 10, 10, SourceTween.MODELTYPE.EXPERIMENTAL))
	_comp.sources.append(SourceBVH.new("Tango Dance", 90, 200, 0, 20, "anim/tango.bvh"))
	_comp.sources.append(SourceTTM.new("Fall", 50, 80, 10, 10, "A person stumbles and falls", SourceTTM.MODELTYPE.EXPERIMENTAL))
	_comp.sources.append(SourceTTM.new("Jump", 20, 60, 5, 5, "The athlete jumps", SourceTTM.MODELTYPE.DEFAULT))
	_comp.sources.append(SourceBVH.new("Capoeira Choreo", 0, 80, 0, 0, "anim/capoeira.bvh"))
	return _comp

func update() -> void:
	properties_panel.update(_composition.sources[_selected_source_idx])
	source_view.update(_composition.sources)
	timeline.update(_composition.sources)

func save_to_file(path: String) -> void:
	ResourceSaver.save(_composition, path)

func load_from_file(path: String) -> void:
	_composition = ResourceLoader.load(path)

func connect_character() -> void:
	var anim_root = world.get_current_skeleton().get_parent().get_path()
	animation_player.set_root(anim_root)

####################### SIGNALS #######################

# func _on_source_changed(source: Source) -> void:
# 	print("Source {0} has been changed".format([source.name]))
# 	update()

# func _on_source_renamed(index: int, new_name: String) -> void:
# 	_composition.sources[index].name = new_name
# 	update()

func _on_source_property_changed(index: int, property: String, value: Variant) -> void:
	print("Source {0} property {1} changed to {2}".format([index, property, value]))
	_composition.sources[index].set(property, value)
	update()

func _on_source_selected(index: int) -> void:
	_selected_source_idx = index
	properties_panel.update(_composition.sources[_selected_source_idx])

func _on_source_added(source: Source) -> void:
	_composition.insert_source(source, 0)
	update()

func _on_composition_changed() -> void:
	print("Composition changed")

func _on_pause_pressed() -> void:
	print("Pause pressed")
	animation_player.pause()

func _on_play_pressed() -> void:
	print("Play pressed")
	animation_player.play()

func _on_stop_pressed() -> void:
	print("Stop pressed")
	animation_player.stop()  # Resets to 0

func _on_seek(seconds: float) -> void:
	print("Seeking to ", seconds)
	animation_player.seek(seconds)

func _on_import_pressed() -> void:
	print("Import pressed")

func _on_generate_pressed() -> void:
	print("Generate pressed")

func _on_save_pressed() -> void:
	print("Save pressed")
	save_to_file("user://saves/composition.tres")

func _on_load_pressed() -> void:
	print("Load pressed")
	load_from_file("user://saves/composition.tres")
	update()

func _on_new_pressed() -> void:
	print("New pressed")
	_composition.clear()

func _on_character_changed() -> void:
	print("Character changed")
	connect_character()
