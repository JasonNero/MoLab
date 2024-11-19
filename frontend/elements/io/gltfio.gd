class_name GLTFIO
extends Object


static func load_animation_from_file(file_path: String, bonemap: BoneMap = null, do_remap: bool = true) -> Animation:
	if !FileAccess.file_exists(file_path):
		printerr("Filename ", file_path, " does not exist or cannot be accessed.")
		return null

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()

	var err := gltf.append_from_file(file_path, state)
	if err != OK:
		printerr("Unable to load model from path {0}".format([file_path]))
		return

	var loaded_scene: Node = gltf.generate_scene(state)
	if loaded_scene == null:
		printerr("Failed to generate scene for model {0}".format([file_path]))
		return

	print("Found ", state.get_skeletons().size(), " skeletons and ", state.get_animations().size(), " animations.")
	var anim_players: Array[Node] = loaded_scene.find_children("*", "AnimationPlayer", true, false)
	if anim_players.size() == 0:
		printerr("No AnimationPlayer found in the loaded scene!")
	var anim_player: AnimationPlayer = anim_players[0]
	var anim_lib :=	anim_player.get_animation_library("")

	# Get the first animation from the library
	var anim := anim_lib.get_animation(anim_lib.get_animation_list()[0]).duplicate() as Animation
	anim.resource_name = file_path.get_file()

	# Free the leftover scene
	loaded_scene.queue_free()

	# Remap the animation to the "%GeneralSkeletion" skeleton
	if do_remap:
		var to_delete: Array[int] = []
		for track_id in range(anim.get_track_count()):
			var track_path = anim.track_get_path(track_id) as String
			var current_bone = track_path.split(":")[1]
			if bonemap != null:
				var remapped_name = bonemap.find_profile_bone_name(current_bone)
				if remapped_name:
					current_bone = remapped_name
			anim.track_set_path(track_id, "%GeneralSkeleton:" + current_bone)

			if anim.track_get_type(track_id) == Animation.TYPE_POSITION_3D:
				# Scale root transform by .01 to convert from cm to m
				# TODO: Make this configurable
				if current_bone == "Hips":
					for key in range(anim.track_get_key_count(track_id)):
						var key_value = anim.track_get_key_value(track_id, key)
						anim.track_set_key_value(track_id, key, key_value * 0.01)
				# Only allow the Hips bone to have a position track
				else:
					to_delete.append(track_id)

		to_delete.reverse()
		for track_id in to_delete:
			anim.remove_track(track_id)

	return anim


static func save_node_to_file(node: Node, file_path: String):
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


static func save_animation_to_file(animation: Animation, file_path: String):
	# This is not as easy as I hoped, maybe using a template scene with
	# an AnimationPlayer and a (empty) skeleton could work?
	# For now, just use the `save_node_to_file` function.
	printerr("Not implemented yet, use `save_node_to_file` instead.")
