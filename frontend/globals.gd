extends Node

var file_tex: Texture2D = preload("res://res/icons/Folder.png")
var ttm_tex: Texture2D = preload("res://res/icons/FontItem.png")
var tween_tex: Texture2D = preload("res://res/icons/Blend.png")

var file_color: Color = Color("#114153")
var ttm_color: Color = Color("#264115")
var tween_color: Color = Color("#134137")

# var FPS: int = 20  # HumanML3D
var FPS: int = 30  # Mixamo

func get_source_icon(source: Source) -> Texture2D:
	if source is SourceFile:
		return Globals.file_tex
	elif source is SourceTTM:
		return Globals.ttm_tex
	elif source is SourceTween:
		return Globals.tween_tex
	else:
		return null

func get_source_color(source: Source) -> Color:
	if source is SourceFile:
		return Globals.file_color
	elif source is SourceTTM:
		return Globals.ttm_color
	elif source is SourceTween:
		return Globals.tween_color
	else:
		return Color("#000000")
