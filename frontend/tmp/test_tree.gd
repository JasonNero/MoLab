@tool
extends Tree


func _ready() -> void:
	set_column_title(0, "Track")
	set_column_title(1, "Type")
	set_column_expand(0, true)


	var root: TreeItem = create_item()
	root.set_text(0, "Custom Group")
	root.set_text(1, "Group")

	var child1: TreeItem = create_item(root)
	child1.set_text(0, "Capoeira Choreo")
	child1.set_text(1, "BVH")

	var child2: TreeItem = create_item(root)
	child2.set_text(0, "Jump")
	child2.set_text(1, "T2M")

	var subchild1: TreeItem = create_item(child2)
	subchild1.set_text(0, "Text")
	subchild1.set_text(1, "A person jumps")
	subchild1.set_editable(1, true)

	child1.collapsed = true


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
