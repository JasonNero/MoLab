class_name TrackAnimation
extends Resource

@export var tracks: Array[Track] = []

func _to_string() -> String:
    var string = "<TrackAnimation#{}>\n".format([get_instance_id()], "{}")
    for track in tracks:
        string += "    " + track.to_string() + "\n"
    return string
