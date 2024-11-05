# source_list.gd
class_name SourceListView
extends Control

signal source_added(source: Source)
signal source_selected(source: Source)
signal source_deleted(source: Source)

@export var item_template: PackedScene
@onready var container: VBoxContainer = %Container
@onready var add_btn: MenuButton = %MenuButton

var source_items: Dictionary = {}  # Source -> Item
var source_btn_group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	var add_popup: PopupMenu = add_btn.get_popup()
	add_popup.add_icon_item(Globals.bvh_tex, "BVH Track")
	add_popup.add_icon_item(Globals.ttm_tex, "TTM Track")
	add_popup.add_icon_item(Globals.tween_tex, "Tween Track")
	add_popup.set_item_icon_max_width(0, 16)
	add_popup.set_item_icon_max_width(1, 16)
	add_popup.set_item_icon_max_width(2, 16)
	add_popup.id_pressed.connect(_on_add_btn_pressed)

func setup(sources: Array[Source]) -> void:
	for source in sources:
		add_source(source)

func insert_source(index: int, source: Source) -> void:
	var item = _create_source_item(source)
	container.move_child(item, index)
	source_items[source] = item

func add_source(source: Source) -> void:
	# Insert source at the end
	insert_source(-1, source)

func remove_source(source: Source) -> void:
	if source in source_items:
		source_items[source].queue_free()
		source_items.erase(source)

func update_source(source: Source) -> void:
	if source in source_items:
		var item = source_items[source]
		item.source_btn.text = source.name

func set_selected(source: Source) -> void:
	for src in source_items:
		var item = source_items[src]
		item.source_btn.button_pressed = (src == source)

func _create_source_item(source: Source) -> SourceListItem:
	var item: SourceListItem = item_template.instantiate()
	container.add_child(item)
	item.source_btn.text = source.name
	item.source_btn.icon = Globals._get_source_icon(source)
	item.source_btn.button_group = source_btn_group
	item.source_btn.pressed.connect(_on_button_pressed.bind(source))
	item.remove_btn.pressed.connect(_on_delete_pressed.bind(source))
	return item

func _on_button_pressed(source: Source) -> void:
	source_selected.emit(source)

func _on_delete_pressed(source: Source) -> void:
	source_deleted.emit(source)

func _on_add_btn_pressed(menu_btn_index: int) -> void:
	var source: Source
	if menu_btn_index == 0:
		source = SourceBVH.new()
	elif menu_btn_index == 1:
		source = SourceTTM.new()
	elif menu_btn_index == 2:
		source = SourceTween.new()
	source_added.emit(source)
