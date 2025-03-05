extends Node

var file_tex: Texture2D = preload("res://res/icons/Animation.png")
var ml_tex: Texture2D = preload("res://res/icons/Terminal.png")

var FPS: float = 20.0 # HumanML3D


func get_source_icon(source: Source) -> Texture2D:
	if source is SourceFile:
		return Globals.file_tex
	elif source is SourceML:
		return Globals.ml_tex
	else:
		return null
