class_name Track
extends RefCounted

@export var name: String

var _clips: Array[Clip]

func add_clip(clip):
	_clips.append(clip)

func remove_clip(clip):
	_clips.erase(clip)

func get_clip(id: int):
	return _clips[id]
