extends Node

var file_tex: Texture2D = preload("res://res/icons/Animation.png")
var ml_tex: Texture2D = preload("res://res/icons/Terminal.png")
# var tween_tex: Texture2D = preload("res://res/icons/Blend.png")

var file_color: Color = Color("#114153")
var ml_color: Color = Color("#264115")
# var tween_color: Color = Color("#134137")

# var FPS: int = 20  # HumanML3D
var FPS: int = 30  # Mixamo


func get_source_icon(source: Source) -> Texture2D:
	if source is SourceFile:
		return Globals.file_tex
	elif source is SourceML:
		return Globals.ml_tex
	else:
		return null

func get_source_color(source: Source) -> Color:
	if source is SourceFile:
		return Globals.file_color
	elif source is SourceML:
		return Globals.ml_color
	else:
		return Color("#000000")

