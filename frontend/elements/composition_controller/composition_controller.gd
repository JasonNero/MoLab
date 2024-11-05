# composition_controller.gd
class_name CompositionController
extends Node

var composition: Composition
var source_view: SourceView
var properties_panel: PropertiesPanel
var time_controls: TimeControls
var animation_composer: AnimationComposer

# Configuration
const MIN_SOURCE_DURATION := 0.1

func initialize(
	p_composition: Composition,
	p_source_view: SourceView,
	p_properties_panel: PropertiesPanel,
	p_time_controls: TimeControls,
	p_animation_composer: AnimationComposer
) -> void:
	composition = p_composition
	source_view = p_source_view
	properties_panel = p_properties_panel
	time_controls = p_time_controls
	animation_composer = p_animation_composer

	_connect_signals()
	_initialize_views()

func _connect_signals() -> void:
	# View signals (user actions)
	source_view.source_added.connect(handle_source_added)
	source_view.source_selected.connect(handle_source_selected)
	source_view.source_moved.connect(handle_source_moved)
	source_view.source_resized.connect(handle_source_resized)
	source_view.source_deleted.connect(handle_source_deleted)

	properties_panel.property_changed.connect(handle_property_changed)

	time_controls.play_pause_pressed.connect(handle_playback_requested)
	time_controls.time_changed.connect(handle_time_changed)
	time_controls.seek_requested.connect(handle_seek_requested)

	# Model signals (state changes)
	composition.source_added.connect(_on_source_added)
	composition.source_removed.connect(_on_source_removed)
	composition.source_modified.connect(_on_source_modified)
	composition.selection_changed.connect(_on_source_selection_changed)

	# Animation signals
	animation_composer.playback_time_changed.connect(_on_playback_time_changed)

func _initialize_views() -> void:
	source_view.setup(composition)
	time_controls.update_time(0)
	time_controls.update_play_state(false)

# Source Management Handlers
func handle_source_added(source: Source) -> void:
	composition.insert_source(source)

func handle_source_selected(source: Source) -> void:
	composition.set_selected_source(source)

func handle_source_moved(source: Source, new_time: int) -> void:
	var old_time := source.in_point
	source.in_point = new_time
	source.out_point = new_time + source.get_duration()

	if _validate_source_position(source):
		composition.source_modified.emit(source)
	else:
		# Revert if invalid
		source.in_point = old_time
		source.out_point = old_time + source.get_duration()
		source_view.update_source_position(source)

func handle_source_resized(source: Source, edge: String, new_time: int) -> void:
	var old_in := source.in_point
	var old_out := source.out_point

	match edge:
		"start":
			source.in_point = new_time
		"end":
			source.out_point = new_time

	if _validate_source_position(source) and source.get_duration() >= MIN_SOURCE_DURATION:
		composition.source_modified.emit(source)
	else:
		# Revert if invalid
		source.in_point = old_in
		source.out_point = old_out
		source_view.update_source_position(source)

func handle_source_deleted(source: Source) -> void:
	composition.remove_source(source)

# Property Management
func handle_property_changed(source: Source, property: String, value: Variant) -> void:
	if _validate_property_change(source, property, value):
		source.set_property(property, value)

		# Mark TTMSource as dirty if needed
		if source is SourceTTM:
			source.mark_dirty()

		composition.source_modified.emit(source)
	else:
		# Revert the property panel value
		properties_panel.update_property(property, source.get_properties()[property].value)

# Playback Control
func handle_playback_requested(should_play: bool) -> void:
	if should_play:
		animation_composer.play()
	else:
		animation_composer.pause()
	time_controls.update_play_state(should_play)

func handle_time_changed(new_time: int) -> void:
	animation_composer.seek(new_time)

func handle_seek_requested(time: int) -> void:
	animation_composer.seek(time)
	time_controls.update_time(time)

# Validation
func _validate_source_position(source: Source) -> bool:
	return source.is_valid()

func _validate_property_change(source: Source, property: String, value: Variant) -> bool:
	match property:
		"name":
			return value.strip_edges().length() > 0
		"in_point", "out_point":
			return value >= 0
		"blend_in", "blend_out":
			return value >= 0 and value <= source.get_duration()
		_:
			return true

# Signal Handlers
func _on_source_added(source: Source) -> void:
	source_view.update_view()
	animation_composer.update_animation()

func _on_source_removed(source: Source) -> void:
	if composition.get_selected_source() == source:
		composition.set_selected_source(null)
	source_view.update_view()
	animation_composer.update_animation()

func _on_source_modified(source: Source) -> void:
	source_view.update_view()
	animation_composer.update_animation()

func _on_source_selection_changed(source: Source) -> void:
	properties_panel.setup_for_source(source)
	source_view.update_selection(source)

func _on_playback_time_changed(time: int) -> void:
	time_controls.update_time(time)
	source_view.update_playhead(time)
