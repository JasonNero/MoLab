# source_view.gd
class_name SourceView
extends Control

signal source_added(source: Source)
signal source_selected(source: Source)
signal source_moved(source: Source, time: float)
signal source_resized(source: Source, edge: String, time: float)
signal source_deleted(source: Source)
signal property_changed(source: Source, property: String, value: Variant)

@onready var source_list: SourceListView = %SourceListView
@onready var timeline: Timeline = %Timeline
# @onready var zoom_slider: HSlider = $ZoomControl/ZoomSlider

var composition: Composition

func _ready() -> void:
	# Connect zoom slider
	# zoom_slider.value_changed.connect(_on_zoom_changed)
	# zoom_slider.min_value = timeline.MIN_PIXELS_PER_SECOND
	# zoom_slider.max_value = timeline.MAX_PIXELS_PER_SECOND
	# zoom_slider.value = timeline.pixels_per_second

	# Connect internal signals
	source_list.source_selected.connect(_on_list_source_selected)
	source_list.source_deleted.connect(_on_list_source_deleted)

	timeline.source_selected.connect(_on_timeline_source_selected)
	timeline.source_moved.connect(_on_timeline_source_moved)
	timeline.source_resized.connect(_on_timeline_source_resized)
	timeline.property_changed.connect(property_changed.emit)

func setup(p_composition: Composition) -> void:
	composition = p_composition

	# Connect composition signals
	composition.source_added.connect(_on_composition_source_added)
	composition.source_removed.connect(_on_composition_source_removed)
	composition.source_modified.connect(_on_composition_source_modified)
	composition.selection_changed.connect(_on_composition_selection_changed)

	# Setup both source list and timeline
	timeline.setup(composition.sources)
	source_list.setup(composition.sources)

func update_playhead(time: float) -> void:
	timeline.set_playhead_position(time)

func update_selection(source: Source) -> void:
	source_list.set_selected(source)
	timeline.set_selected(source)

# Source list signal handlers
func _on_list_source_selected(source: Source) -> void:
	source_selected.emit(source)

func _on_list_source_deleted(source: Source) -> void:
	source_deleted.emit(source)

# Timeline signal handlers
func _on_timeline_source_selected(source: Source) -> void:
	source_selected.emit(source)

func _on_timeline_source_moved(source: Source, time: float) -> void:
	source_moved.emit(source, time)

func _on_timeline_source_resized(source: Source, edge: String, time: float) -> void:
	source_resized.emit(source, edge, time)

# Composition signal handlers
func _on_composition_source_added(index: int, source: Source) -> void:
	source_list.insert_source(index, source)
	timeline.insert_source(index, source)

func _on_composition_source_removed(source: Source) -> void:
	source_list.remove_source(source)
	timeline.remove_source(source)

func _on_composition_source_modified(source: Source) -> void:
	source_list.update_source(source)
	timeline.update_source(source)

func _on_composition_selection_changed(source: Source) -> void:
	update_selection(source)

# Zoom control
func _on_zoom_changed(value: float) -> void:
	timeline.pixels_per_second = value
	timeline.queue_redraw()
