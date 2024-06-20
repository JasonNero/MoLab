extends Node2D


func _draw():
	var size = get_viewport_rect().size  * get_parent().get_node("Camera2D").zoom / 2
	var cam = get_parent().get_node("Camera2D").position

	for i in range(
			int((cam.x - size.x) / 64) - 1,
			int((size.x + cam.x) / 64) + 1
		):
		draw_line(Vector2(i * 64, cam.y + size.y + 100), Vector2(i * 64, cam.y - size.y - 100), "000000")

	for i in range(
			int((cam.y - size.y) / 64) - 1,
			int((size.y + cam.y) / 64) + 1
		):
		draw_line(Vector2(cam.x + size.x + 100, i * 64), Vector2(cam.x - size.x - 100, i * 64), "000000")
