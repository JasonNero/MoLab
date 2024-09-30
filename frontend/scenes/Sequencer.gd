class_name Sequencer
extends PanelContainer

@onready var track_tree = %TrackTree
@onready var track_panel = %TrackPanel
@onready var timeline = %TimelineScrollBar

var trackanim: TrackAnimation

func _ready() -> void:
	trackanim = _get_placeholder_anim()
	save_track_animation(trackanim, "res://saves/test_anim.tres")
	trackanim = load_track_animation("res://saves/test_anim.tres")
	print(trackanim)

	show_tracks(trackanim.tracks)
	_connect_signals()

func _connect_signals():
	track_tree.item_collapsed.connect(_on_collapse)
	track_tree.item_selected.connect(_on_tree_item_selected)
	track_panel.item_selected.connect(_on_panel_item_selected)

func _disconnect_signals():
	track_tree.item_collapsed.disconnect(_on_collapse)

func load_track_animation(path: String) -> TrackAnimation:
	print("Loading animation from path ", path)
	return ResourceLoader.load(path)

func save_track_animation(anim: TrackAnimation, path: String) -> void:
	ResourceSaver.save(anim, path)

func _get_placeholder_anim() -> TrackAnimation:
	var _anim = TrackAnimation.new()
	_anim.tracks.append(BVHTrack.new("Capoeira Choreo", 0, 80, 0, 0, "anim/capoeira.bvh"))
	_anim.tracks.append(TTMTrack.new("Jump", 20, 60, 5, 5, "The athlete jumps", TTMTrack.MODELTYPE.DEFAULT))
	_anim.tracks.append(TTMTrack.new("Fall", 50, 80, 10, 10, "A person stumbles and falls", TTMTrack.MODELTYPE.EXPERIMENTAL))
	_anim.tracks.append(BVHTrack.new("Tango Dance", 90, 200, 0, 20, "anim/capoeira.bvh"))
	_anim.tracks.append(TweenTrack.new("Transition", 70, 100, 10, 10, TweenTrack.MODELTYPE.EXPERIMENTAL))
	return _anim

func add_track(track: Track):
	var tree_item: TreeItem = track_tree.add_track_item(track)
	var tree_item_y = track_tree.get_item_area_rect(tree_item).position.y
	var _panel_item = track_panel.add_track_item(track, tree_item_y)

func show_tracks(tracks: Array[Track]):
	track_tree.clear()
	track_panel.clear()

	for track in tracks:
		add_track(track)

func _on_collapse(_collapsed_item: TreeItem):
	# Update the tree to panel alignment after collapse/expand
	var track_count := trackanim.tracks.size()

	for track_id in range(track_count):
		var tree_item = track_tree.get_root().get_child(track_id)
		var panel_item = track_panel.items[track_id]

		var tree_item_y = track_tree.get_item_area_rect(tree_item).position.y
		panel_item.position.y = tree_item_y

	# Update minimum size for panel scrollbar
	var full_size = track_tree.get_full_size()
	track_panel.custom_minimum_size = full_size

func _on_tree_item_selected():
	var item: TreeItem = track_tree.get_selected()
	print("tree_item_selected: ", item)
	# track_panel.select_item_at()


func _on_panel_item_selected(item):
	print("panel_item_selected: ", item)
