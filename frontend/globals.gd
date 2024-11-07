extends Node

var bvh_tex: Texture2D = preload("res://res/icons/Folder.png")
var ttm_tex: Texture2D = preload("res://res/icons/FontItem.png")
var tween_tex: Texture2D = preload("res://res/icons/Blend.png")

var bvh_color: Color = Color("#114153")
var ttm_color: Color = Color("#264115")
var tween_color: Color = Color("#134137")

var FPS: int = 25

func _get_source_icon(source: Source) -> Texture2D:
	if source is SourceBVH:
		return Globals.bvh_tex
	elif source is SourceTTM:
		return Globals.ttm_tex
	elif source is SourceTween:
		return Globals.tween_tex
	else:
		return null
