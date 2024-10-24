class_name TrackTree
extends Tree

static var _column_names := [
	"Track Name",
	# "",
]
static var icon_size := 16

########################################################################
# TODO: Custom root_item_selected signal to select the corresponding panel item in Sequencer
# TODO: Introduce "time", connecting the Timeline
# TODO: Draw a time-indicator over/onto the TrackPanel
########################################################################

func _ready() -> void:
	columns = len(_column_names)
	column_titles_visible = false

	for col_id in range(columns):
		set_column_title(col_id, _column_names[col_id])

	hide_root = true

func get_or_create_root() -> TreeItem:
	var root: TreeItem = get_root()
	if not root:
		root = create_item()
	return root

## Return the size of all TreeItems combined.
func get_full_size() -> Vector2:
	var last_item_rect = get_item_area_rect(get_or_create_root().get_child( - 1))
	var full_size = last_item_rect.position + last_item_rect.size
	return full_size

func add_source_item(source: Source, collapsed=true) -> TreeItem:
	var root: TreeItem = get_or_create_root()

	var item: TreeItem = create_item(root)
	item.set_icon(0, Globals._get_source_icon(source))
	item.set_icon_max_width(0, icon_size)
	item.set_text(0, source.name)

	# # Base Track Options
	# var track_options: TreeItem = create_item(item)
	# track_options.set_text(0, "Track Options")

	# var track_options_in: TreeItem = create_item(track_options)
	# track_options_in.set_text(0, "In Point")
	# track_options_in.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	# track_options_in.set_range(1, source.in_point)
	# track_options_in.set_editable(1, true)

	# var track_options_out: TreeItem = create_item(track_options)
	# track_options_out.set_text(0, "Out Point")
	# track_options_out.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	# track_options_out.set_range(1, source.out_point)
	# track_options_out.set_editable(1, true)

	# # Track Type Options
	# if source is SourceBVH:
	# 	_setup_bvh_options(item, source)
	# elif source is SourceTTM:
	# 	_setup_ttm_options(item, source)
	# elif source is SourceTween:
	# 	_setup_tween_options(item, source)

	# item.set_collapsed_recursive(collapsed)
	return item

# func _setup_bvh_options(item: TreeItem, source: SourceBVH):
# 	var bvh_options: TreeItem = create_item(item)
# 	bvh_options.set_text(0, "BVH Options")

# 	var bvh_options_file: TreeItem = create_item(bvh_options)
# 	bvh_options_file.set_text(0, "File")
# 	bvh_options_file.set_text(1, source.file)
# 	bvh_options_file.set_editable(1, true)

# func _setup_tween_options(item: TreeItem, source: SourceTween):
# 	var gen_options: TreeItem = create_item(item)
# 	gen_options.set_text(0, "Generation Options")

# 	var gen_options_model: TreeItem = create_item(gen_options)
# 	gen_options_model.set_text(0, "Model")
# 	gen_options_model.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)

# 	var keys = SourceTween.MODELTYPE.keys()
# 	keys.push_front(keys.pop_at(source.model)) # Put the selected mode first
# 	gen_options_model.set_text(1, ",".join(keys))
# 	gen_options_model.set_editable(1, true)

# func _setup_ttm_options(item: TreeItem, source: SourceTTM):
# 	var gen_options: TreeItem = create_item(item)
# 	gen_options.set_text(0, "Generation Options")

# 	var gen_options_text: TreeItem = create_item(gen_options)
# 	gen_options_text.set_text(0, "Text")
# 	gen_options_text.set_text(1, source.text)
# 	gen_options_text.set_editable(1, true)

# 	var gen_options_model: TreeItem = create_item(gen_options)
# 	gen_options_model.set_text(0, "Model")
# 	gen_options_model.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)

# 	var keys = SourceTTM.MODELTYPE.keys()
# 	keys.push_front(keys.pop_at(source.model)) # Put the selected mode first
# 	gen_options_model.set_text(1, ",".join(keys))
# 	gen_options_model.set_editable(1, true)

# ####################################################################################
# Drag&Drop adapted from:
# https://forum.godotengine.org/t/dragging-treeitems-within-tree-control-node/42393/2

# TODO: This throws off the items in the panel since the order changed
#		-> Keep track of their IDs instead?

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
