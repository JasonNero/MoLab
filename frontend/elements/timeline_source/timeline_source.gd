# timeline_source.gd
class_name TimelineSource
extends Control

const SELECTION_BORDER_COLOR := Color(0.2, 0.8, 1.0, 1.0)  # Light blue
const SELECTION_FILL_COLOR := Color(0.2, 0.8, 1.0, 0.1)    # Transparent light blue
const SELECTION_BORDER_WIDTH := 2.0
const SELECTION_CORNER_RADIUS := 4.0
const HANDLE_SIZE := 6.0  # Size of resize handles

var source: Source
var selected: bool = false
var rect: Rect2

func update_rect(new_rect: Rect2) -> void:
    rect = new_rect
    position = rect.position
    size = rect.size
    queue_redraw()

func _draw() -> void:
    _draw_background()
    _draw_blend_regions()
    if selected:
        _draw_selection()
    _draw_label()

func _draw_background() -> void:
    var style = get_theme_stylebox("panel")
    style.draw(get_canvas_item(), Rect2(Vector2(), size))

func _draw_blend_regions() -> void:
    if source.blend_in > 0:
        var blend_width = source.blend_in * get_parent().pixels_per_second
        draw_rect(Rect2(0, 0, blend_width, size.y), Color(0.2, 0.5, 1.0, 0.3))

    if source.blend_out > 0:
        var blend_width = source.blend_out * get_parent().pixels_per_second
        draw_rect(Rect2(size.x - blend_width, 0, blend_width, size.y),
                 Color(0.2, 0.5, 1.0, 0.3))

func _draw_label() -> void:
    var font = get_theme_font("normal")
    draw_string(font, Vector2(5, size.y/2), source.name)

func _draw_selection() -> void:
    # Draw selection fill
    draw_rect(
        Rect2(Vector2(), size),
        SELECTION_FILL_COLOR,
        true,  # filled
        SELECTION_CORNER_RADIUS
    )

    # Draw selection border
    draw_rect(
        Rect2(Vector2(), size),
        SELECTION_BORDER_COLOR,
        false,  # not filled
        SELECTION_CORNER_RADIUS,
        SELECTION_BORDER_WIDTH
    )

    # Draw resize handles on left and right edges
    _draw_resize_handle(Vector2(0, size.y / 2))            # Left handle
    _draw_resize_handle(Vector2(size.x, size.y / 2))       # Right handle

func _draw_resize_handle(center: Vector2) -> void:
    # Draw handle background (white circle)
    draw_circle(
        center,
        HANDLE_SIZE,
        Color.WHITE
    )

    # Draw handle border
    draw_arc(
        center,
        HANDLE_SIZE,
        0,          # start angle
        TAU,        # end angle (full circle)
        16,         # number of segments
        SELECTION_BORDER_COLOR,
        SELECTION_BORDER_WIDTH,
        true        # antialiased
    )
