@tool
@icon("res://addons/about_dialog/assets/about_dialog.svg")
extends AcceptDialog
class_name AboutDialog
## A simple about dialog node for the Godot game engine.
## After importing, simply add a [AboutDialog] node in the editor.
## Automatically displays the projects name, version and description as put in the [ProjectSettings], although this can all be overridden.
## The advanced settings allow for the format of the title and body of the dialog to be configured.

# A private collection of all the names of the properties intended to be hidden.
const _HIDDEN_PROPERTIES:Array[String] = ["dialog_text", "title"]
# A private collection of all the [Signal]s to be listened to for updating the dialog body.
var _EXTERNAL_UPDATE_SIGNALS:Array[Signal] = [ProjectSettings.settings_changed, visibility_changed]

## All possible attributed of the window that can be overridden.
@export_group("Overrides")
## Override the name of the project as used in this [AboutDialog].
@export var name_override:= "":
	get:
		return name_override
	set(value):
		name_override = value
		update_dialog()
## Override the version of the project as used in this [AboutDialog].
@export var version_override:= "":
	get:
		return version_override
	set(value):
		version_override = value
		update_dialog()
## Override the description of the project as used in this [AboutDialog].
@export var description_override:= "":
	get:
		return description_override
	set(value):
		description_override = value
		update_dialog()
## These settings do not have to be modified unless you really need to
@export_subgroup("Advanced")
## The prefix in the [member AboutDialog.title_substutions] and [member AboutDialog.body_substutions] [Array]s,
## used to signal that it should be replaced with the relevant project setting shorthand or path,
## if possible.
## There 3 shorthand paths, these paths also apply their respictive overrides:[br]
## - name : The project name[br]
## - version : The project version[br]
## - description : The project description
@export var substution_prefix:= "%":
	get:
		return substution_prefix
	set(value):
		substution_prefix = value
		update_dialog()
## A [String] meant to be formated with the [member AboutDialog.title_substutions] array and used as the title.
@export var title_format:= "About %s":
	get:
		return title_format
	set(value):
		title_format = value
		update_dialog()
## A [Array] of [String]s meant to be substituted into [member AboutDialog.title_substutions].
## Any [String] that starts with the [member AboutDialog.substution_prefix] will first be attempted to be replaced with
## the appropriate shorthand [ProjectSettings] setting, or full [ProjectSettings] path, if possible.
## There 3 shorthand paths, these paths also apply their respictive overrides:[br]
## - name : The project name[br]
## - version : The project version[br]
## - description : The project description
@export var title_substutions:Array[String] = [substution_prefix + "name"]:
	get:
		return title_substutions
	set(value):
		title_substutions = value
		update_dialog()
## A [String] meant to be formated with the [member AboutDialog.body_substutions] array and used as the body.
@export_multiline var body_format:= "%s v%s\n%s":
	get:
		return body_format
	set(value):
		body_format = value
		update_dialog()
## A [Array] of [String]s meant to be substituted into [member AboutDialog.body_substutions].
## Any [String] that starts with the [member AboutDialog.substution_prefix] will first be attempted to be replaced with
## the appropriate shorthand [ProjectSettings] setting, or full [ProjectSettings] path, if possible.
## There 3 shorthand paths, these paths also apply their respictive overrides:[br]
## - name : The project name[br]
## - version : The project version[br]
## - description : The project description
@export var body_substutions:Array[String] = [substution_prefix + "name", substution_prefix + "version", substution_prefix + "description"]:
	get:
		return body_substutions
	set(value):
		body_substutions = value
		update_dialog()


# Connects all the appropriate singals if possible.
func _enter_tree():
	update_dialog()
	for sig in _EXTERNAL_UPDATE_SIGNALS:
		if not sig.is_connected(update_dialog):
			sig.connect(update_dialog)


# Connects all the appropriate singals if possible.
# This is used here again to avoid any accidental delinks
# if the editor resets the connectons by accident while this is still loaded.
func _ready():
	update_dialog()
	for sig in _EXTERNAL_UPDATE_SIGNALS:
		if not sig.is_connected(update_dialog):
			sig.connect(update_dialog)


# Disonnects all the appropriate singals, if possible.
func _exit_tree():
	for sig in _EXTERNAL_UPDATE_SIGNALS:
		if sig.is_connected(update_dialog):
			sig.disconnect(update_dialog)


# Used to hide the inherited properties that are overridden by this script.
func _validate_property(property:Dictionary):
	if property.name in _HIDDEN_PROPERTIES:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Reloads the title and body of the dialog.
## Used internally in [AboutDialog].
## It is not necessary to call this manually.
func update_dialog():
	dialog_text = body_format % _resolve_subs(body_substutions)
	title = title_format % _resolve_subs(title_substutions)


## Gets the name that the body and title will reference where appropriate.
func get_relevant_name() -> String:
	const PATH:= "application/config/name"
	if name_override.is_empty() and ProjectSettings.has_setting(PATH):
		var temp_name = ProjectSettings.get_setting_with_override(PATH)
		temp_name = temp_name.strip_edges()
		if not temp_name.is_empty():
			return temp_name
	return name_override


## Gets the version that the body and title will reference where appropriate.
func get_relevant_version() -> String:
	const PATH:= "application/config/version"
	if version_override.is_empty() and ProjectSettings.has_setting(PATH):
		var temp_version = ProjectSettings.get_setting_with_override(PATH)
		temp_version = temp_version.strip_edges()
		if not temp_version.is_empty():
			return temp_version 
	return version_override


## Gets the description that the body and title will reference where appropriate.
func get_relevant_description() -> String:
	const PATH:= "application/config/description"
	if description_override.is_empty() and ProjectSettings.has_setting(PATH):
		var temp_description = ProjectSettings.get_setting_with_override(PATH)
		temp_description = temp_description.strip_edges()
		if not temp_description.is_empty():
			return temp_description 
	return description_override


# Takes a [i]x[/i]_substitutions array and transfroms any 
# appropriately prefixed and existant project setting path with the relevant value.
func _resolve_subs(sub_array:Array[String]) -> Array[String]:
	var resulting_subs:Array[String] = []
	for sub in sub_array:
		sub = sub.strip_edges()
		if sub == substution_prefix + "name":
			sub = get_relevant_name()
		elif sub == substution_prefix + "version":
			sub = get_relevant_version()
		elif sub == substution_prefix + "description":
			sub = get_relevant_description()
		elif sub.left(substution_prefix.length()) == substution_prefix:
			var trimmed = sub.trim_prefix(substution_prefix)
			if ProjectSettings.has_setting(trimmed):
				sub = ProjectSettings.get_setting_with_override(trimmed)
		resulting_subs.append(sub)
	return resulting_subs
