extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var model_in_path := "res://res/models/Passive_Marker_Man.glb"
	var loaded_model = load_gltf(model_in_path)
	add_child(loaded_model)

	var model_out_path := "res://tmp/io_test_markerman.glb"
	save_gltf(loaded_model, model_out_path)


func load_gltf(file_path: String) -> Node:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	var err := gltf.append_from_file(file_path, state)
	if err != OK:
		printerr("Unable to load model from path {0}".format([file_path]))
		return

	var loaded_model: Node = gltf.generate_scene(state)
	if loaded_model == null:
		printerr("Failed to generate scene for model {0}".format([file_path]))
		return

	print(state.get_animations())
	print(state.get_skeletons())

	return loaded_model


func save_gltf(node: Node, file_path: String):
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	var err := gltf.append_from_scene(node, state)
	if err != OK:
		printerr("Unable to save model")
		return

	err = gltf.write_to_filesystem(state, file_path)
	if err != OK:
		printerr("Unable to save model to path {0}".format([file_path]))
		return
