class_name Sequence
extends RefCounted

var _tracks: Array[Track]

func get_track_count() -> int:
	return len(_tracks)

func get_track(id: int) -> Track:
	return _tracks[id]

func get_tracks() -> Array[Track]:
	return _tracks

func get_track_by_name(name: String) -> Track:
	for track in _tracks:
		if track.name == name:
			return track
	return

func add_track(track: Track) -> int:
	_tracks.append(track)
	return get_track_count()
