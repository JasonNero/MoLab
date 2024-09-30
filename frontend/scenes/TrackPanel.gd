class_name TrackPanel
extends Panel

signal item_selected(item)

var default_style: StyleBox
var bvh_style: StyleBox
var ttm_style: StyleBox
var tween_style: StyleBox

var items: Array
var zoom: int = 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var temp_btn = Button.new()
	default_style = temp_btn.get_theme_stylebox("normal").duplicate()
	temp_btn.queue_free()

	bvh_style = default_style.duplicate()
	bvh_style.bg_color = Globals.bvh_color
	ttm_style = default_style.duplicate()
	ttm_style.bg_color = Globals.ttm_color
	tween_style = default_style.duplicate()
	tween_style.bg_color = Globals.tween_color


func _get_track_style(track: Track) -> StyleBox:
	if track is BVHTrack:
		return bvh_style
	elif track is TTMTrack:
		return ttm_style
	elif track is TweenTrack:
		return tween_style
	else:
		return default_style


func clear():
	while items:
		items.pop_back().queue_free()


func add_track_item(track: Track, y_position: int):
	var track_item := Button.new()
	track_item.icon = Globals._get_track_icon(track)
	track_item.expand_icon = true
	track_item.set_position(Vector2(track.in_point, y_position) * Vector2(zoom, 1))
	track_item.set_size(Vector2(track.out_point - track.in_point, 27) * Vector2(zoom, 1))
	track_item.add_theme_stylebox_override("normal", _get_track_style(track))
	track_item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track_item.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(track_item)
	track_item.pressed.connect(func(): item_selected.emit(track_item))
	items.append(track_item)

	return track_item


func select_item_at(idx: int):
	var item: Button = items[idx]
	item.grab_focus()


func _draw():
	var x_step = 16
	var y_step = 31

	for i in range(
			0,
			int(size.x / x_step) + 1
		):
		draw_line(
			Vector2(i * x_step, 0),
			Vector2(i * x_step, size.y),
			"000000"
		)

	for i in range(
			0,
			int(size.y / y_step) + 1
		):
		draw_line(
			Vector2(0, i * y_step),
			Vector2(size.x, i * y_step),
			"000000"
		)
