# This BVH Importer is adapted from
# https://github.com/JosephCatrambone/godot-bvh-import

# We keep in our bone_to_index_map a mapping of bone names (string) to an array of indices.  The index values are determined by this:
const XPOS = "Xposition"
const YPOS = "Yposition"
const ZPOS = "Zposition"
const XROT = "Xrotation"
const YROT = "Yrotation"
const ZROT = "Zrotation"
var channel_names = [XPOS, YPOS, ZPOS, XROT, YROT, ZROT]
var channel_index_map = {
	XPOS: 0,
	YPOS: 1,
	ZPOS: 2,
	XROT: 3,
	YROT: 4,
	ZROT: 5
}
# Constants we use in our config.
const SKELETON_PATH = "skeleton_path"
const ANIM_PLAYER_NAME = "animation_player_name"
const NEW_ANIM_NAME = "new_animation_name"
const IGNORE_OFFSETS = "ignore_offsets"
const TRANSFORM_SCALING = "transform_scaling"
const BONE_REMAPPING_JSON = "bone_remapping_json"
var AXIS_ORDERING_NAMES = ["Native", "XYZ", "XZY", "YXZ", "YZX", "ZXY", "ZYX", "Reverse Native"]
enum AXIS_ORDERING {NATIVE = 0, XYZ, XZY, YXZ, YZX, ZXY, ZYX, REVERSE}
const AXIS_ORDER = "force_axis_ordering"
const FORWARD_VECTOR = "forward_vector"
const UP_VECTOR = "up_vector"
const RIGHT_VECTOR = "right_vector"

# Godot + OpenGL are left-handed.  -Z is forward.  +Y is up.
# Blender:
# GX1 -> +X is right.
# GZ1 -> +Z is up.
# GY1 -> +Y is forward.

func get_config_data() -> Dictionary:
	# Reads from our UI and returns a dictionary of String -> Value.
	# This will do all of the node reading and accessing, next to ready.
	var config = Dictionary()
	# config[SKELETON_PATH] = skeleton_path_input.text
	# config[ANIM_PLAYER_NAME] = animation_player_name_input.text
	# config[NEW_ANIM_NAME] = animation_name_input.text
	# config[IGNORE_OFFSETS] = ignore_offsets_option.pressed
	# config[TRANSFORM_SCALING] = transform_scaling_spinbox.value
	# config[AXIS_ORDER] = axis_ordering_dropdown.selected
	# config[RIGHT_VECTOR] = Vector3(x_axis_remap_x.value, x_axis_remap_y.value, x_axis_remap_z.value)
	# config[UP_VECTOR] = Vector3(y_axis_remap_x.value, y_axis_remap_y.value, y_axis_remap_z.value)
	# config[FORWARD_VECTOR] = Vector3(z_axis_remap_x.value, z_axis_remap_y.value, z_axis_remap_z.value)
	# config[BONE_REMAPPING_JSON] = JSON.new().parse(remapping_json_input.text)

	config = {
		"skeleton_path": "Armature",
		"animation_player_name": "AnimationPlayer",
		"new_animation_name": "BVH Animation 00",
		# Rest can be left at default
		"ignore_offsets": false,
		"transform_scaling": 1,
		"force_axis_ordering": 0,
		"right_vector": Vector3(1, 0, 0),
		"up_vector": Vector3(0, 1, 0),
		"forward_vector": Vector3(0, 0, 1),
		"bone_remapping_json": {}
	}

	return config

#
# Ideally the material below should not touch UI.  Everything here is concerned with importing and manipulating BVH.
# The user interface and reading of config data should happen above here.
# Global configurations and tweaks should go into the config data.
#

func _make_animation(file: String):
	var config = get_config_data()
	var animation = load_bvh_filename(file)

	var animation_player: AnimationPlayer = EditorInterface.get_edited_scene_root().get_node(config[ANIM_PLAYER_NAME])
	if animation_player == null:
		printerr("AnimationPlayer is null. Trying selection instead.")
		var editor_selection = EditorInterface.get_selection()
		var selected_nodes = editor_selection.get_selected_nodes()
		if len(selected_nodes) == 0:
			printerr("No nodes selected. Please select the target animation player.")
			return
		elif selected_nodes[0] is AnimationPlayer:
			animation_player = selected_nodes[0]
			print("AnimationPlayer found: ", animation_player)
		else:
			printerr("No AnimationPlayer selected. Please select the target animation player.")
			return

	var animation_name = config[NEW_ANIM_NAME]
	var animation_lib: AnimationLibrary = animation_player.get_animation_library(animation_player.get_animation_library_list()[0])

	if animation_lib.has_animation(animation_name):
		# TODO: Animation exists.  Prompt to overwrite.
		animation_lib.remove_animation(animation_name)

	animation_lib.add_animation(animation_name, animation)
	animation_player.set_current_animation(animation_name)

func load_bvh_filename(filename: String) -> Animation:
	if !FileAccess.file_exists(filename):
		printerr("Filename ", filename, " does not exist or cannot be accessed.")
		return null
	var file = FileAccess.open(filename, FileAccess.READ) # "user://some_data"
	var plaintext = file.get_as_text()

	var parsed_file = parse_bvh(plaintext)
	var hierarchy_lines = parsed_file[0]
	var motion_lines = parsed_file[1]

	var hdata = parse_hierarchy(hierarchy_lines)
	var bone_names: Array = hdata[0]
	var bone_index_map: Dictionary = hdata[1]
	var bone_offsets: Dictionary = hdata[2]

	return parse_motion(bone_names, bone_index_map, bone_offsets, motion_lines)

func parse_bvh(fulltext: String) -> Array:
	# Split the fulltext by the elements from HIERARCHY to MOTION, and MOTION until the end of file.
	# Returns an array of [[hierarchy lines], [motion lines]]
	var lines = fulltext.split("\n", false)
	var hierarchy_lines: Array = Array()
	var motion_lines: Array = Array()
	var hierarchy_section = false
	var motion_section = false

	for line in lines:
		line = line.strip_edges()
		# As written, we'll skip the 'hierarchy' and 'motion' lines.
		if line.begins_with("HIERARCHY"):
			hierarchy_section = true
			motion_section = false
			continue
		elif line.begins_with("MOTION"):
			motion_section = true
			hierarchy_section = false
			continue

		if hierarchy_section:
			hierarchy_lines.append(line)
		elif motion_section:
			motion_lines.append(line)

	return [hierarchy_lines, motion_lines]

func parse_hierarchy(text: Array): # -> [String, Array, Dictionary, Dictionary]:
	# Given the plaintext HIERARCHY from HIERARCHY until MOTION,
	# pull out the bones AND the order of the features AND the bone offsets,
	# returning a list of the order of the element names.
	# We don't apply any bone remapping in here.
	var bone_names: Array = Array()
	var bone_index_map: Dictionary = Dictionary() # Maps from bone name to a map of *POS -> value.
	var bone_offsets: Dictionary = Dictionary()

	# NOTE: We are not keeping the structure of the hierarchy because we don't need it.
	# We only need the order of the channels and names of the bones.

	var data_index: int = 0
	var current_bone = ""
	for line in text:
		line = line.strip_edges()
		if line.begins_with("ROOT"):
			current_bone = line.split(" ", false)[1].replace(":", "_")
			bone_names.append(current_bone)
			bone_index_map[current_bone] = Dictionary()
			bone_offsets[current_bone] = Vector3()
		elif line.begins_with("CHANNELS"):
			var data: Array = line.split(" ", false)
			var num_channels = data[1].to_int()
			print("Reading " + str(num_channels) + " data channel(s) for bone " + current_bone)
			for c in range(num_channels):
				var chan = data[2 + c]
				bone_index_map[current_bone][chan] = data_index
				print(current_bone + " " + chan + ": " + str(data_index))
				data_index += 1
		elif line.begins_with("JOINT"):
			current_bone = line.split(" ", false)[1].replace(":", "_")
			bone_names.append(current_bone)
			bone_index_map[current_bone] = Dictionary() # -1 means not in collection.
			bone_offsets[current_bone] = Vector3()
		elif line.begins_with("OFFSET"):
			var data: Array = line.split(" ", false)
			bone_offsets[current_bone].x = data[1].to_float()
			bone_offsets[current_bone].y = data[2].to_float()
			bone_offsets[current_bone].z = data[3].to_float()

	return [bone_names, bone_index_map, bone_offsets]

# WARNING: This method will mutate the input text array.
func parse_motion(bone_names: Array, bone_index_map: Dictionary, bone_offsets: Dictionary, text: Array) -> Animation:
	var config = get_config_data()

	var rig_name = config[SKELETON_PATH]

	var num_frames = 0
	var timestep = 0.033333
	var read_header = true
	while read_header:
		read_header = false
		if text[0].begins_with("Frames:"):
			num_frames = text[0].split(" ")[1].to_int()
			text.pop_front()
			read_header = true
		if text[0].begins_with("Frame Time:"):
			timestep = text[0].split(" ")[2].to_float()
			text.pop_front()
			read_header = true

	var animation: Animation = Animation.new()

	# Set the length of the animation to match the BVH length.
	animation.length = num_frames * timestep

	# Create new tracks.
	var element_track_index_map: Dictionary = Dictionary()
	for i in range(len(bone_names)):
		var pos_track_index = animation.add_track(Animation.TYPE_POSITION_3D)
		var rot_track_index = animation.add_track(Animation.TYPE_ROTATION_3D)
		# Note: Hitting the keyframe button on the pose data will insert a value track with bones/##/pose,
		# but this doesn't appear to work for the replay.  Use a transform track instead of Animation.TYPE_VALUE.
		element_track_index_map[i] = pos_track_index

	var step: int = 0
	for line in text:
		var values = line.strip_edges().split_floats(" ", false)
		for bone_index in range(len(bone_names)):
			var pos_track_index = element_track_index_map[bone_index]
			var rot_track_index = pos_track_index + 1
			var bone_name = bone_names[bone_index]

			# Use negative one so that if we forget a check we fail early and get an index error, rather than bad data.
			var translation_x_index = bone_index_map[bone_name].get(XPOS, -1)
			var translation_y_index = bone_index_map[bone_name].get(YPOS, -1)
			var translation_z_index = bone_index_map[bone_name].get(ZPOS, -1)
			var rotation_x_index = bone_index_map[bone_name].get(XROT, -1)
			var rotation_y_index = bone_index_map[bone_name].get(YROT, -1)
			var rotation_z_index = bone_index_map[bone_name].get(ZROT, -1)

			var translation = Vector3()
			if not config[IGNORE_OFFSETS]: # These are the _starting_ offsets, not the translations.
				translation = Vector3(
					bone_offsets[bone_name].x,
					bone_offsets[bone_name].y,
					bone_offsets[bone_name].z
				) # Clone this vector so we don't change it between steps.
			if translation_x_index != -1:
				translation.x += values[translation_x_index]
			if translation_y_index != -1:
				translation.y += values[translation_y_index]
			if translation_z_index != -1:
				translation.z += values[translation_z_index]
			translation *= config[TRANSFORM_SCALING]

			# Godot: +X right, -Z forward, +Y up.
			# BVH: +Y up.
			var raw_rotation_values: Vector3 = Vector3(0, 0, 0)
			# NOTE: raw_rot is Not actually anything like axis-angle, just a convenient placeholder for a triple.
			raw_rotation_values.x = values[rotation_x_index]
			raw_rotation_values.y = values[rotation_y_index]
			raw_rotation_values.z = values[rotation_z_index]

			# Apply joint rotations.
			if config[AXIS_ORDER] == AXIS_ORDERING.REVERSE:
				# Something of a hack.  We take the indices in order and sort them, by flipping the index sign we take them in reverse order.
				rotation_x_index = -rotation_x_index
				rotation_y_index = -rotation_y_index
				rotation_z_index = -rotation_z_index
			elif config[AXIS_ORDER] != AXIS_ORDERING.NATIVE:
				rotation_x_index = AXIS_ORDERING_NAMES[config[AXIS_ORDER]].find('X')
				rotation_y_index = AXIS_ORDERING_NAMES[config[AXIS_ORDER]].find('Y')
				rotation_z_index = AXIS_ORDERING_NAMES[config[AXIS_ORDER]].find('Z')
			var rotation = _bvh_zxy_to_quaternion(raw_rotation_values.x, raw_rotation_values.y, raw_rotation_values.z, rotation_x_index, rotation_y_index, rotation_z_index)
			# CAVEAT SCRIPTOR: rotation_*_index is not valid after this operation!

			# Apply bone-name remapping _just_ before we actually set the track.
			if config[BONE_REMAPPING_JSON] and bone_name in config[BONE_REMAPPING_JSON]:
				bone_name = config[BONE_REMAPPING_JSON][bone_name]
				# TODO: Option to skip unmapped bones.  Leaving as is for now because people can remove them manually.

			animation.track_set_path(pos_track_index, rig_name + ":" + bone_name)
			animation.track_set_path(rot_track_index, rig_name + ":" + bone_name)

			if bone_index == 0:
				animation.position_track_insert_key(pos_track_index, step * timestep, translation)
			animation.rotation_track_insert_key(rot_track_index, step * timestep, rotation)

		step += 1

	return animation

class FirstIndexSort:
	static func sort_ascending(a, b):
		if a[0] > b[0]:
			return true
		return false

func _bvh_zxy_to_quaternion(x: float, y: float, z: float, x_idx: int, y_idx: int, z_idx: int) -> Quaternion:
	# From BVH documentation: "it goes Z rotation, followed by the X rotation and finally the Y rotation."
	# But there are some applications which change the ordering.
	var config = get_config_data()
	var rotation := Quaternion.IDENTITY
	var x_rot = Quaternion(config[RIGHT_VECTOR], deg_to_rad(x))
	var y_rot = Quaternion(config[UP_VECTOR], deg_to_rad(y))
	var z_rot = Quaternion(config[FORWARD_VECTOR], deg_to_rad(z))
	# This is a lazy way of sorting the actions into appropriate order.
	var rotation_matrices = [[x_idx, x_rot], [y_idx, y_rot], [z_idx, z_rot]]
	rotation_matrices.sort_custom(FirstIndexSort.sort_ascending)
	for r in rotation_matrices:
		rotation *= r[1]
	return rotation
