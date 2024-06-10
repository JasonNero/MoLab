#@tool
class_name TrackTree
extends Tree

static var _column_names := [
	"Track Name",
	"",
]
static var _icon_size := 16

@export var bvh_tex: Texture2D
@export var ttm_tex: Texture2D
@export var tween_tex: Texture2D

########################################################################
# TODO: Draw the clips in the separate panel using the Animation instance
# TODO: Draw a custom HScrollBar aka our Timeline
########################################################################

@export var anim: TrackAnimation

func _ready() -> void:
	if not anim or len(anim.tracks) == 0:
		print("No or empty TrackAnimation, using placeholder")
		anim = _get_placeholder_anim()
	# ResourceSaver.save(anim, "res://tmp/trackanim.tres")

	_setup_ui()


func _get_placeholder_anim() -> TrackAnimation:
	var _anim = TrackAnimation.new()
	_anim.tracks.append(BVHTrack.new("Capoeira Choreo", 0, 80, 0, 0, "anim/capoeira.bvh"))
	_anim.tracks.append(TTMTrack.new("Jump", 20, 60, 5, 5, "The athlete jumps", TTMTrack.MODELTYPE.DEFAULT))
	_anim.tracks.append(TTMTrack.new("Fall", 50, 80, 10, 10, "A person stumbles and falls", TTMTrack.MODELTYPE.EXPERIMENTAL))
	_anim.tracks.append(BVHTrack.new("Tango Dance", 90, 200, 0, 20, "anim/capoeira.bvh"))
	_anim.tracks.append(TweenTrack.new("Transition", 70, 100, 10, 10, TweenTrack.MODELTYPE.EXPERIMENTAL))
	return _anim

func _get_track_icon(track: Track) -> Texture2D:
	if track is BVHTrack:
		return bvh_tex
	elif track is TTMTrack:
		return ttm_tex
	elif track is TweenTrack:
		return tween_tex
	else:
		return get_theme_icon("close")

func _setup_ui():
	columns = len(_column_names)
	column_titles_visible = false

	for col_id in range(columns):
		set_column_title(col_id, _column_names[col_id])

	var root: TreeItem = create_item()
	root.set_text(0, "ROOT")
	hide_root = true

	for track in anim.tracks:
		var child: TreeItem = create_item(root)
		child.set_icon(0, _get_track_icon(track))
		child.set_icon_max_width(0, _icon_size)
		child.set_text(1, track.name)
		_setup_track_options(child, track)

	# collapse all and then show root
	root.set_collapsed_recursive(true)
	root.collapsed = false

func _setup_track_options(
		item: TreeItem,
		track: Track,
	):
	# Base Track Options
	var track_options: TreeItem = create_item(item)
	track_options.set_text(0, "Track Options")

	var track_options_in: TreeItem = create_item(track_options)
	track_options_in.set_text(0, "In Point")
	track_options_in.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	track_options_in.set_range(1, track.in_point)
	track_options_in.set_editable(1, true)

	var track_options_out: TreeItem = create_item(track_options)
	track_options_out.set_text(0, "Out Point")
	track_options_out.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	track_options_out.set_range(1, track.out_point)
	track_options_out.set_editable(1, true)

	# Track Type Options
	if track is BVHTrack:
		_setup_bvh_options(item, track)
	elif track is TTMTrack:
		_setup_ttm_options(item, track)
	elif track is TweenTrack:
		_setup_tween_options(item, track)


func _setup_bvh_options(
		item: TreeItem,
		track: BVHTrack,
	):
	var bvh_options: TreeItem = create_item(item)
	bvh_options.set_text(0, "BVH Options")

	var bvh_options_file: TreeItem = create_item(bvh_options)
	bvh_options_file.set_text(0, "File")
	bvh_options_file.set_text(1, track.file)
	bvh_options_file.set_editable(1, true)

func _setup_tween_options(
		item: TreeItem,
		track: TweenTrack,
	):
	var gen_options: TreeItem = create_item(item)
	gen_options.set_text(0, "Generation Options")

	var gen_options_model: TreeItem = create_item(gen_options)
	gen_options_model.set_text(0, "Model")
	gen_options_model.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	gen_options_model.set_text(1, ",".join(TweenTrack.MODELTYPE.keys()))
	# TODO: Figure out how to set the correct item
	gen_options_model.set_editable(1, true)

func _setup_ttm_options(
		item: TreeItem,
		track: TTMTrack
	):
	var gen_options: TreeItem = create_item(item)
	gen_options.set_text(0, "Generation Options")

	var gen_options_text: TreeItem = create_item(gen_options)
	gen_options_text.set_text(0, "Text")
	gen_options_text.set_text(1, track.text)
	gen_options_text.set_editable(1, true)

	var gen_options_model: TreeItem = create_item(gen_options)
	gen_options_model.set_text(0, "Model")
	gen_options_model.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	gen_options_model.set_text(1, ",".join(TTMTrack.MODELTYPE.keys()))
	# TODO: Figure out how to set the correct item
	gen_options_model.set_editable(1, true)

# Drag&Drop adapted from:
# https://forum.godotengine.org/t/dragging-treeitems-within-tree-control-node/42393/2

func _get_drag_data(_at_position: Vector2) -> Variant:
	var items := []
	var next: TreeItem = get_next_selected(null)
	var v := VBoxContainer.new()
	while next:
		if get_root() == next.get_parent():
			items.append(next)
			var l := Label.new()
			l.text = next.get_text(0)
			v.add_child(l)
		next = get_next_selected(next)
	set_drag_preview(v)
	return items

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	drop_mode_flags = Tree.DROP_MODE_INBETWEEN
	var drop_section := get_drop_section_at_position(at_position)
	if drop_section == - 100:
		return false
	var item := get_item_at_position(at_position)
	if item.get_parent() != get_root():
		return false # only drag under root
	if item in data:
		return false
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drop_section := get_drop_section_at_position(at_position)
	var other_item := get_item_at_position(at_position)

	for i in data.size():
		var item := data[i] as TreeItem
		if drop_section == - 1:
			item.move_before(other_item)
		elif drop_section == 1:
			if i == 0:
				item.move_after(other_item)
			else:
				item.move_after(data[i - 1])
