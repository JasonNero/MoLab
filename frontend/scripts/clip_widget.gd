#@tool

extends Control
class_name ClipWidget

@onready var _inner_panel = %InnerPanel

@export_category("Clip")
@export var start : int:
	set(new_start):
		start = new_start
		call_deferred("update_ui")  # otherwise, we get an error during init

@export var end : int:
	set(new_end):
		end = new_end
		call_deferred("update_ui")  # otherwise, we get an error during init

@export var inPoint : int:
	set(new_inPoint):
		inPoint = new_inPoint
		call_deferred("update_ui")  # otherwise, we get an error during init

@export var outPoint : int:
	set(new_outPoint):
		outPoint = new_outPoint
		call_deferred("update_ui")  # otherwise, we get an error during init

@export_placeholder("a person  ...") var text: String = "drunk guy walking"

var startPos : Vector2
var initialPos : Vector2
var moveX : bool
var resizeX : bool
var initialSize : Vector2
@export var GrabThreshold := 20
@export var ResizeThreshold := 5

# TODO: Try this official drag&drop example
#		https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html#mouse-motion


# Called when the node enters the scene tree for the first time.
func _ready():
	%LineEdit.text = text


func _gui_input(event: InputEvent) -> void:
	print(event)

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		var globalPos = get_global_position()
		var localMousePos = event.position
		var rect = get_rect()

		if abs(localMousePos.y) < GrabThreshold:
			startPos = event.position
			initialPos = get_position()
			moveX = true
		else:
			if abs(localMousePos.x - rect.size.x) < ResizeThreshold:
				startPos.x = localMousePos.x
				initialSize.x = get_size().x
				resizeX = true

			if localMousePos.x < ResizeThreshold &&  localMousePos.x > -ResizeThreshold:
				startPos.x = localMousePos.x
				initialPos.x = get_position().x
				initialSize.x = get_size().x
				resizeX = true

	if Input.is_action_pressed("LeftMouseDown"):
		var localMousePos = event.position

		if moveX:
			var new_position = initialPos
			new_position.x = localMousePos.x - startPos.x
			set_position(new_position)

		if resizeX:
			var newWidth = get_size().x
			var newHeight = get_size().y

			newWidth = initialSize.x - (startPos.x - localMousePos.x)

			if initialPos.x != 0:
				newWidth = initialSize.x + (startPos.x - localMousePos.x)
				set_position(Vector2(initialPos.x - (newWidth - initialSize.x), get_position().y))

			set_size(Vector2(newWidth, newHeight))


	if Input.is_action_just_released("LeftMouseDown"):
		moveX = false
		resizeX = false
		initialPos = Vector2(0,0)


func update_ui():
	set_position(Vector2(start, position.y))
	set_size(Vector2(end - start, size.y))
	_inner_panel.set_position(Vector2(inPoint, _inner_panel.position.y))
	_inner_panel.set_size(Vector2(outPoint - inPoint, _inner_panel.size.y))
	#print("ui update called")
