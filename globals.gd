extends Node

var bvh_tex: Texture2D = preload("res://icons/Folder.png")
var ttm_tex: Texture2D = preload("res://icons/FontItem.png")
var tween_tex: Texture2D = preload("res://icons/Blend.png")

var bvh_color: Color = Color("#114153")
var ttm_color: Color = Color("#264115")
var tween_color: Color = Color("#134137")


func _get_track_icon(track: Track) -> Texture2D:
	if track is BVHTrack:
		return Globals.bvh_tex
	elif track is TTMTrack:
		return Globals.ttm_tex
	elif track is TweenTrack:
		return Globals.tween_tex
	else:
		return null
