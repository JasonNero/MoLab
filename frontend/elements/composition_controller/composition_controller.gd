# composition_controller.gd
class_name CompositionController
extends Node

var composition: Composition
var menu_bar: MenuBar
var source_view: SourceView
var properties_panel: PropertiesPanel
var time_controls: TimeControls
var animation_composer: AnimationComposer
var file_access_web: FileAccessWeb

func initialize(
	p_composition: Composition,
	p_menu_bar: MenuBar,
	p_source_view: SourceView,
	p_properties_panel: PropertiesPanel,
	p_time_controls: TimeControls,
	p_animation_composer: AnimationComposer
) -> void:
	composition = p_composition
	menu_bar = p_menu_bar
	source_view = p_source_view
	properties_panel = p_properties_panel
	time_controls = p_time_controls
	animation_composer = p_animation_composer

	_connect_signals()
	_initialize_views()

func _connect_signals() -> void:
	menu_bar.new_composition_clicked.connect(_on_new_composition_clicked)
	menu_bar.open_composition_clicked.connect(_on_open_composition_clicked)
	menu_bar.save_composition_clicked.connect(_on_save_composition_clicked)
	menu_bar.export_composition_clicked.connect(_on_export_composition_clicked)
	menu_bar.about_clicked.connect(_on_about_clicked)

	# View signals (user actions)
	source_view.source_added.connect(_on_view_source_added)
	source_view.source_selected.connect(_on_view_source_selected)
	source_view.source_deleted.connect(_on_view_source_deleted)
	source_view.source_moved.connect(_on_view_source_moved)
	source_view.property_changed.connect(_on_view_property_changed)
	source_view.playhead_moved.connect(_on_seek_requested)

	properties_panel.property_changed.connect(_on_view_property_changed)

	time_controls.play_pause_pressed.connect(_on_playback_requested)
	time_controls.seek_requested.connect(_on_seek_requested)

	# Animation signals
	animation_composer.playback_time_changed.connect(_on_playback_time_changed)

	# Backend signals
	Backend.results_received.connect(_on_result_received)

	if OS.get_name() == "Web":
		file_access_web = FileAccessWeb.new()

func _initialize_views() -> void:
	properties_panel.setup(composition)
	source_view.setup(composition)
	time_controls.update_time(0)
	time_controls.update_play_state(false)

func _on_new_composition_clicked(_dict) -> void:
	composition.clear()

func _on_open_composition_clicked(_dict) -> void:
	if OS.get_name() == "Web":
		file_access_web.loaded.connect(_on_file_loaded_web)
		file_access_web.open("*.tres,*.res")
	else:
		# TODO: Create a FileDialog scene instead
		var dialog: FileDialog = find_child("OpenDialog")
		if dialog == null:
			dialog = FileDialog.new()
			# dialog.use_native_dialog = true
			dialog.name = "OpenDialog"
			dialog.access = FileDialog.ACCESS_USERDATA
			dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			dialog.add_filter("*.tres,*.res", "Composition")
			dialog.file_selected.connect(_on_file_dialog_composition_selected)
			add_child(dialog)
		dialog.popup_centered(Vector2(600, 400))

func _on_file_loaded_web(file_name: String, file_type: String, base64_data: String) -> void:
	print("File loaded: ", file_name, file_type)
	print("Base64: ", base64_data)

	if file_type == "application/x-godot-resource":
		var data_raw : PackedByteArray = Marshalls.base64_to_raw(base64_data)
		var data_utf8 = Marshalls.base64_to_utf8(base64_data)
		print("Raw: ", data_raw)
		print("UTF8: ", data_utf8)

		var file = FileAccess.open("user://uploaded.tres", FileAccess.WRITE)
		file.store_buffer(data_raw)
		file.close()

		var resource = ResourceLoader.load("user://uploaded.tres")
		print("Resource: ", resource)
		var new_composition = resource as Composition
		print("Composition: ", new_composition)
		if new_composition:
			composition.clear()
			composition.name = new_composition.name
			var reversed_sources = new_composition.sources
			reversed_sources.reverse()
			for source in reversed_sources:
				composition.insert_source(source)
				composition.source_modified.emit(source)
	else:
		push_warning("Invalid file type: ", file_type)
	file_access_web.loaded.disconnect(_on_file_loaded_web)

func _on_file_dialog_composition_selected(filepath: String) -> void:
	# TODO: Implement this properly (do I need to reconnect all signals?...)
	var new_composition = ResourceLoader.load(filepath) as Composition
	if new_composition:
		print("Clearing")
		composition.clear()
		composition.name = new_composition.name
		var reversed_sources = new_composition.sources
		reversed_sources.reverse()
		for source in reversed_sources:
			print("Adding source: ", source.name)
			composition.insert_source(source)
			composition.source_modified.emit(source)

func _on_save_composition_clicked(_dict) -> void:
	# TODO: Cleanup this hack and add a save dialog
	(get_parent() as MainEditor).save_composition()

func _on_export_composition_clicked(_dict) -> void:
	print("Exporting composition to GLTF...")
	var character_node = get_parent().find_child("GeneralSkeleton").get_parent()

	var dialog: FileDialog = find_child("ExportDialog")
	if dialog == null:
		dialog = FileDialog.new()
		# dialog.use_native_dialog = true
		dialog.name = "ExportDialog"
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.add_filter("*.gltf,*.glb", "glTF")
		dialog.file_selected.connect(
			func (filepath: String) -> void: GLTFIO.save_node_to_file(character_node, filepath)
		)
		add_child(dialog)
	dialog.popup_centered(Vector2(600, 400))

	# GLTFIO.save_node_to_file(character_node, "user://exported_scene.gltf")

func _on_about_clicked(_dict) -> void:
	%AboutDialog.show()

# Source Management Handlers
func _on_view_source_added(source: Source) -> void:
	composition.insert_source(source)

func _on_view_source_selected(source: Source) -> void:
	composition.set_selected_source(source)

func _on_view_source_deleted(source: Source) -> void:
	composition.remove_source(source)

func _on_view_source_moved(source: Source, in_point: int) -> void:
	var delta = in_point - source.in_point
	source.in_point = in_point
	source.out_point += delta
	composition.source_modified.emit(source)

func _validate_source_position(source: Source) -> bool:
	return source.is_valid()

func _validate_property_change(source: Source, property: String, value: Variant) -> bool:
	# TODO: Move this to the Source(s)
	match property:
		"name":
			return value.strip_edges().length() > 0
		"in_point":
			return source.animation == null and value < source.out_point
		"out_point":
			return source.animation == null and value > source.in_point
		"in_offset":
			return (
				value >= 0 and
				value <= (source.out_point - source.in_point - source.out_offset)
			)
		"out_offset":
			return (
				value >= 0 and
				value <= (source.out_point - source.in_point - source.in_offset)
			)
		_:
			return true

func _on_view_property_changed(source: Source, property: String, value: Variant) -> void:
	# Select the source if it's not already selected
	if composition.get_selected_source() != source:
		composition.set_selected_source(source)

	# Validate the property change before applying it
	if _validate_property_change(source, property, value):
		# print("Valid property change: ", property, value)
		source.set_property(property, value)

		composition.source_modified.emit(source)
	else:
		push_warning("Invalid property change: ", property, value)
		# Revert the property panel value
		properties_panel.set_property_view_value(property, source.get_properties()[property].value)
		# The other views do not need to be reverted, as they are bound to the source

# Playback Control
func _on_playback_requested(should_play: bool) -> void:
	if should_play:
		animation_composer.play()
	else:
		animation_composer.pause()
	time_controls.update_play_state(should_play)

func _on_time_changed(new_time: float) -> void:
	animation_composer.seek(new_time)

func _on_seek_requested(time: float) -> void:
	animation_composer.seek(time)
	time_controls.update_time(time)

func _on_playback_time_changed(time: float) -> void:
	time_controls.update_time(time)
	source_view.update_playhead(time)

func _on_result_received(results: InferenceResults) -> void:
	# HACK: Refreshing the source view to update the source's animation
	composition.set_selected_source(null)
