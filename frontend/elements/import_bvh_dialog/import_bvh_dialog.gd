class_name ImportBVHDialog
extends FileDialog

# This BVH Importer is adapted from
# https://github.com/JosephCatrambone/godot-bvh-import

signal animation_imported(animation: Animation)

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
var AXIS_ORDERING_NAMES = ["Native", "XYZ", "XZY", "YXZ", "YZX", "ZXY", "ZYX", "Reverse Native"]
enum AXIS_ORDERING {NATIVE = 0, XYZ, XZY, YXZ, YZX, ZXY, ZYX, REVERSE}
const AXIS_ORDER = "force_axis_ordering"

var config = {
	"skeleton_path": "%GeneralSkeleton",
	# Rest can be left at default
	"ignore_offsets": false,
	"transform_scaling": 1,
	"force_axis_ordering": 0,
	"right_vector": Vector3(1, 0, 0),
	"up_vector": Vector3(0, 1, 0),
	"forward_vector": Vector3(0, 0, 1),
	"bone_remapping_json": {}
}


@export var bonemap: BoneMap

func _ready() -> void:
	file_selected.connect(_on_file_selected)

#
# Ideally the material below should not touch UI.  Everything here is concerned with importing and manipulating BVH.
# The user interface and reading of config data should happen above here.
# Global configurations and tweaks should go into the config data.
#

func _on_file_selected(file: String):
	var animation_name = file.get_file()  # Godot String function to get just the filename.
	var animation := _load_bvh_filename(file)
	animation.resource_name = animation_name
	animation_imported.emit(animation)

func _load_bvh_filename(filename: String) -> Animation:
	if !FileAccess.file_exists(filename):
		printerr("Filename ", filename, " does not exist or cannot be accessed.")
		return null
	var file = FileAccess.open(filename, FileAccess.READ) # "user://some_data"
	var plaintext = file.get_as_text()

	var parsed_file = _parse_bvh(plaintext)
	var hierarchy_lines = parsed_file[0]
	var motion_lines = parsed_file[1]

	var hdata = parse_hierarchy(hierarchy_lines)
	var bone_names: Array = hdata[0]
	var bone_index_map: Dictionary = hdata[1]
	var bone_offsets: Dictionary = hdata[2]

	return _parse_motion(bone_names, bone_index_map, bone_offsets, motion_lines)

func _parse_bvh(fulltext: String) -> Array:
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
			# print("Reading " + str(num_channels) + " data channel(s) for bone " + current_bone)
			for c in range(num_channels):
				var chan = data[2 + c]
				bone_index_map[current_bone][chan] = data_index
				# print(current_bone + " " + chan + ": " + str(data_index))
				data_index += 1
		elif line.begins_with("JOINT"):
			current_bone = line.split(" ", false)[1].replace(":", "_")
			var remapped_name = bonemap.find_profile_bone_name(current_bone)
			if remapped_name:
				current_bone = remapped_name
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
func _parse_motion(bone_names: Array, bone_index_map: Dictionary, bone_offsets: Dictionary, text: Array) -> Animation:
	var rig_name = config["skeleton_path"]

	var num_frames = 0
	var timestep = 1.0/Globals.FPS
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
	print("Loading Animation with ", num_frames, " at ", 1.0/timestep, " FPS.")
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
			if not config["ignore_offsets"]: # These are the _starting_ offsets, not the translations.
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
			translation *= config["transform_scaling"]

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
			if bone_name == "LeftUpLeg":
				print("LeftUpLeg Rotation Conversion")
				print("\tRaw :  ", raw_rotation_values)
				print("\tQuat:  ", rotation)
				print("\tEuler: ", rotation.get_euler() * 57.2958)  # Convert to degrees.
			# CAVEAT SCRIPTOR: rotation_*_index is not valid after this operation!

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

# func _bvh_zxy_to_quaternion(x: float, y: float, z: float, x_idx: int, y_idx: int, z_idx: int) -> Quaternion:
# 	# From BVH documentation: "it goes Z rotation, followed by the X rotation and finally the Y rotation."
# 	# But there are some applications which change the ordering.
# 	var rotation := Quaternion.from_euler(Vector3(deg_to_rad(y), deg_to_rad(x), deg_to_rad(z)))
# 	return rotation

func _bvh_zxy_to_quaternion(x: float, y: float, z: float, x_idx: int, y_idx: int, z_idx: int) -> Quaternion:
	# From BVH documentation: "it goes Z rotation, followed by the X rotation and finally the Y rotation."
	# But there are some applications which change the ordering.
	var rotation := Quaternion.IDENTITY
	var x_rot = Quaternion(config["right_vector"], deg_to_rad(x))  	# TODO: Make sure this needs to be Radians
	var y_rot = Quaternion(config["up_vector"], deg_to_rad(y))		# TODO: Make sure this needs to be Radians
	var z_rot = Quaternion(config["forward_vector"], deg_to_rad(z))	# TODO: Make sure this needs to be Radians

	# This is a lazy way of sorting the actions into appropriate order.
	var rotation_matrices = [[x_idx, x_rot], [y_idx, y_rot], [z_idx, z_rot]]
	rotation_matrices.sort_custom(FirstIndexSort.sort_ascending)
	for r in rotation_matrices:
		rotation *= r[1]
	return rotation

	# return x_rot * y_rot * z_rot
	# return z_rot * y_rot * x_rot
