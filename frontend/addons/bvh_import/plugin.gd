@tool
extends EditorPlugin

#
# Plugin boilerplate and housekeeping.
#

var dock

func _enter_tree():
	# Initialization of the plugin goes here
	# Load the dock scene and instance it
	dock = preload("res://addons/bvh_import/dock.tscn").instantiate()
	dock.editor_interface = get_editor_interface()

	# Add the loaded scene to the docks
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, dock)

func _exit_tree():
	# Free memory.  Clean up signals.
	remove_control_from_docks(dock)
	dock.free()

