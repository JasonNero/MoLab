# source_view.gd
class_name SourceView
extends Control

signal source_added(source: Source)
signal source_selected(source: Source)
signal source_moved(source: Source, time: float)
signal source_deleted(source: Source)
signal property_changed(source: Source, property: String, value: Variant)

@onready var source_list: SourceListView = %SourceListView
@onready var timeline: Timeline = %Timeline

var composition: Composition

func _ready() -> void:
	# Bubble up signals from sub-views
	source_list.source_added.connect(source_added.emit)
	source_list.source_selected.connect(source_selected.emit)
	source_list.source_deleted.connect(source_deleted.emit)
	timeline.source_selected.connect(source_selected.emit)
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
