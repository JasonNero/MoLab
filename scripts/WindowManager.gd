extends Control

# SOURCE: https://github.com/finepointcgi/Drag-Rescale-and-Drop-Windows/blob/main/WindowManager.gd


var startPos : Vector2
var initialPos : Vector2
var moveX : bool
var resizeX : bool
var initialSize : Vector2
@export var GrabThreshold := 20
@export var ResizeThreshold := 5

func _input(event):
	if Input.is_action_just_pressed("LeftMouseDown"):
		#var rect = get_global_rect()

		var localMousePos = event.position - get_global_position()
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
		var localMousePos = event.position - get_global_position()

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
