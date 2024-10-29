class_name SourceView
extends VBoxContainer

@export var icon_size: int = 16

@export var item_tree: Tree
@export var add_menu: MenuButton

# signal source_renamed(index: int, new_name: String)
signal source_property_changed(index: int, property: String, value: Variant)
signal source_selected(index: int)
signal source_added(source: Source)

var previous_selected_item: TreeItem

# Called when the node enters the scene item_tree for the first time.
func _ready() -> void:
	var popup = add_menu.get_popup()
	popup.add_icon_item(Globals.bvh_tex, "BVH Source", 0)
	popup.add_icon_item(Globals.ttm_tex, "Text To Motion", 1)
	popup.add_icon_item(Globals.tween_tex, "Tween", 2)
	# TODO: Use a theme instead?
	popup.set_item_icon_max_width(0, icon_size)
	popup.set_item_icon_max_width(1, icon_size)
	popup.set_item_icon_max_width(2, icon_size)

	popup.index_pressed.connect(_on_add_menu_item_selected)

func update(sources: Array[Source]) -> void:
	item_tree.clear()
	item_tree.create_item()
	item_tree.set_hide_root(true)
	for source in sources:
		var item := item_tree.create_item(item_tree.get_root())
		item.set_text(0, source.name)
		item.set_icon(0, Globals._get_source_icon(source))
		item.set_icon_max_width(0, icon_size)
		# TODO: Use `add_button` to add Solo/Mute/Delete buttons later on

####################### SIGNALS #######################

func _on_tree_item_selected() -> void:
	var index = item_tree.get_selected().get_index()
	print("Selected item: {0}".format([index]))
	source_selected.emit(index)

# Activated by double-clicking or Enter key
func _on_tree_item_activated():
	var item = item_tree.get_selected()
	print("Activated item: {0}".format([item.get_index()]))
	item.set_editable(0, true)

	if previous_selected_item != null and previous_selected_item != item:
		previous_selected_item.set_editable(0, false)
	previous_selected_item = item

func _on_add_menu_item_selected(index: int) -> void:
	match index:
		0:
			source_added.emit(SourceBVH.new("New BVH Source"))
		1:
			source_added.emit(SourceTTM.new("New TTM Source"))
		2:
			source_added.emit(SourceTween.new("New Tween Source"))

func _on_tree_item_edited() -> void:
	var item = item_tree.get_selected()
	print("Edited item: {0}".format([item.get_index()]))
	item.set_editable(0, false)
	# source_renamed.emit(item.get_index(), item.get_text(0))
	source_property_changed.emit(item.get_index(), "name", item.get_text(0))
