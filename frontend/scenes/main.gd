class_name Sequencer
# extends PanelContainer
extends Node

@onready var source_tree = %SourceTree
@onready var source_panel = %SourcePanel
@onready var properties_box: PropertiesBox = %LayerPropertiesBox
@onready var timeline = %TimelineScrollBar

var _composition: Composition

func _ready() -> void:
	_composition = _get_placeholder_comp()
	# save_track_animation(_composition, "res://saves/test_anim.tres")
	# _composition = load_track_animation("res://saves/test_anim.tres")
	print(_composition)

	show_sources(_composition.sources)
	_connect_signals()

func _connect_signals():
	source_tree.item_selected.connect(_on_tree_item_selected)
	source_panel.item_selected.connect(_on_panel_item_selected)

func _disconnect_signals():
	pass

func load_track_animation(path: String) -> Composition:
	print("Loading animation from path ", path)
	return ResourceLoader.load(path)

func save_track_animation(anim: Composition, path: String) -> void:
	ResourceSaver.save(anim, path)

func _get_placeholder_comp() -> Composition:
	var _comp = Composition.new()
	_comp.sources.append(SourceTween.new("Transition", 70, 100, 10, 10, SourceTween.MODELTYPE.EXPERIMENTAL))
	_comp.sources.append(SourceBVH.new("Tango Dance", 90, 200, 0, 20, "anim/tango.bvh"))
	_comp.sources.append(SourceTTM.new("Fall", 50, 80, 10, 10, "A person stumbles and falls", SourceTTM.MODELTYPE.EXPERIMENTAL))
	_comp.sources.append(SourceTTM.new("Jump", 20, 60, 5, 5, "The athlete jumps", SourceTTM.MODELTYPE.DEFAULT))
	_comp.sources.append(SourceBVH.new("Capoeira Choreo", 0, 80, 0, 0, "anim/capoeira.bvh"))
	return _comp

func add_source(source: Source):
	var tree_item: TreeItem = source_tree.add_source_item(source)
	var tree_item_y = source_tree.get_item_area_rect(tree_item).position.y
	var _panel_item = source_panel.add_source_item(source, tree_item_y)

func show_sources(sources: Array[Source]):
	source_tree.clear()
	source_panel.clear()

	for source in sources:
		add_source(source)

func _on_tree_item_selected():
	var item: TreeItem = source_tree.get_selected()
	print("tree_item_selected: ", item)
	# source_panel.select_item_at()
	properties_box.clear()
	properties_box.add_group(item.get_text(0))

func _on_panel_item_selected(item):
	print("panel_item_selected: ", item)
