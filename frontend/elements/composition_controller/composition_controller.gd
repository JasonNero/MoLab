# composition_controller.gd
class_name CompositionController
extends Node

var composition: Composition
var source_view: SourceView
var properties_panel: PropertiesPanel
var time_controls: TimeControls
var animation_composer: AnimationComposer

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
	source_view.source_added.connect(_on_view_source_added)
	source_view.source_selected.connect(_on_view_source_selected)
	source_view.source_deleted.connect(_on_view_source_deleted)
	source_view.source_moved.connect(_on_view_source_moved)
	source_view.property_changed.connect(_on_view_property_changed)

	properties_panel.property_changed.connect(_on_view_property_changed)

	time_controls.play_pause_pressed.connect(_on_playback_requested)
	time_controls.time_changed.connect(_on_time_changed)
	time_controls.seek_requested.connect(_on_seek_requested)

	# Animation signals
	animation_composer.playback_time_changed.connect(_on_playback_time_changed)

func _initialize_views() -> void:
	properties_panel.setup(composition)
	source_view.setup(composition)
	time_controls.update_time(0)
	time_controls.update_play_state(false)

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

		# Mark TTMSource as dirty if needed
		if source is SourceTTM:
			source.mark_dirty()

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

func _on_time_changed(new_time: int) -> void:
	animation_composer.seek(new_time)

func _on_seek_requested(time: int) -> void:
	animation_composer.seek(time)
	time_controls.update_time(time)

func _on_playback_time_changed(time: int) -> void:
	time_controls.update_time(time)
	source_view.update_playhead(time)
