class_name ImportDialog
extends FileDialog

# This BVH Importer is adapted from
# https://github.com/JosephCatrambone/godot-bvh-import

signal animation_imported(animation: Animation)

@export var bonemap: BoneMap

func _ready() -> void:
	file_selected.connect(_on_file_selected)

func _on_file_selected(filepath: String):
	var animation: Animation = null
	match filepath.get_extension():
		"gltf", "glb":
			animation = GLTFIO.load_animation_from_file(filepath, bonemap)
		"bvh":
			printerr("BVH Importer temporarily removed...")
		_:
			print("Unknown file type: ", filepath.get_extension())

	if animation != null:
		animation_imported.emit(animation)
