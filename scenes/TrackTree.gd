@tool
extends Tree

static var _columns := [
	"Track Name",
	"",
	""
]

static var _icon_size := 16

@export var bvh_tex : Texture2D
@export var ttm_tex : Texture2D
@export var tween_tex : Texture2D





########################################################################
# TODO: 1. Create custom "Animation" Resource and "Track" Class
#		-> 	Transfer all of the examples over
# TODO: 2. Adapt _ready to generate the TreeItems from Animation instance.
# TODO: ~~3. Experiment with a custom draw for CELL_MODE_CUSTOM~~
#       -> 	The columns are not resizable by hand, rather use the separate panel
#			for drawing the actual clip-boxes
# TODO: 4. Draw the clips in the separate panel using the Animation instance
# TODO: 5. Draw a custom HScrollBar aka our Timeline
########################################################################


func _ready() -> void:

	# COLUMN & ROOT SETUP

	columns = len(_columns)
	column_titles_visible = true

	for col_id in range(columns):
		set_column_title(col_id, _columns[col_id])

	var root: TreeItem = create_item()
	root.set_text(0, "ROOT")
	hide_root = true

	# ITEM SETUP

	var child1: TreeItem = create_item(root)
	child1.set_icon(0, bvh_tex)
	child1.set_icon_max_width(0, _icon_size)
	child1.set_text(0, "Capoeira Choreo")

	var child2: TreeItem = create_item(root)
	child2.set_icon(0, ttm_tex)
	child2.set_icon_max_width(0, _icon_size)
	child2.set_text(0, "Jump")

	var child3: TreeItem = create_item(root)
	child3.set_icon(0, ttm_tex)
	child3.set_icon_max_width(0, _icon_size)
	child3.set_text(0, "Fall")

	var child4: TreeItem = create_item(root)
	child4.set_icon(0, bvh_tex)
	child4.set_icon_max_width(0, _icon_size)
	child4.set_text(0, "Tango Dance")

	var child5: TreeItem = create_item(root)
	child5.set_icon(0, tween_tex)
	child5.set_icon_max_width(0, _icon_size)
	child5.set_text(0, "Transition")

	# OPTIONS SETUP

	_setup_track_options(child1, 0, 80)
	_setup_track_options(child2, 20, 60)
	_setup_t2m_options(child2, "The athlete jumps")
	_setup_track_options(child3, 50, 80)
	_setup_t2m_options(child3, "A person stumbles")
	_setup_track_options(child4, 90, 150)
	_setup_track_options(child5, 75, 95)
	_setup_tween_options(child5)

	# collapse all and then show root
	root.set_collapsed_recursive(true)
	root.collapsed = false


func _setup_track_options(
		item: TreeItem,
		inpoint: int,
		outpoint: int,
	):

	var track_options: TreeItem = create_item(item)
	track_options.set_text(0, "Track Options")

	var track_options_in: TreeItem = create_item(track_options)
	track_options_in.set_text(0, "In Point")
	track_options_in.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	track_options_in.set_range(1, inpoint)
	track_options_in.set_editable(1, true)

	var track_options_out: TreeItem = create_item(track_options)
	track_options_out.set_text(0, "Out Point")
	track_options_out.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	track_options_out.set_range(1, outpoint)
	track_options_out.set_editable(1, true)


func _setup_tween_options(
		item: TreeItem,
	):

	var gen_options: TreeItem = create_item(item)
	gen_options.set_text(0, "Generation Options")

	var gen_options_model: TreeItem = create_item(gen_options)
	gen_options_model.set_text(0, "Model")
	gen_options_model.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	gen_options_model.set_text(1, "Default,Experimental,Legacy")
	gen_options_model.set_editable(1, true)


func _setup_t2m_options(
		item: TreeItem,
		text: String,
	):

	var gen_options: TreeItem = create_item(item)
	gen_options.set_text(0, "Generation Options")

	var gen_options_text: TreeItem = create_item(gen_options)
	gen_options_text.set_text(0, "Text")
	gen_options_text.set_text(1, text)
	gen_options_text.set_editable(1, true)

	var gen_options_model: TreeItem = create_item(gen_options)
	gen_options_model.set_text(0, "Model")
	gen_options_model.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	gen_options_model.set_text(1, "Default,Experimental,Legacy")
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
	if drop_section == -100:
		return false
	var item := get_item_at_position(at_position)
	if item.get_parent() != get_root():
		return false  # only drag under root
	if item in data:
		return false
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drop_section := get_drop_section_at_position(at_position)
	var other_item := get_item_at_position(at_position)

	for i in data.size():
		var item := data[i] as TreeItem
		if drop_section == -1:
			item.move_before(other_item)
		elif drop_section == 1:
			if i == 0:
				item.move_after(other_item)
			else:
				item.move_after(data[i - 1])
