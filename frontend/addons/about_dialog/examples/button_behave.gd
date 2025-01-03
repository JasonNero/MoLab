extends Button

@export var about_dialog_ref:AboutDialog = null

func show_dialog():
    if about_dialog_ref != null:
        about_dialog_ref.visible = true

func _enter_tree():
    if not pressed.is_connected(show_dialog):
        pressed.connect(show_dialog)

func _exit_tree():
    if pressed.is_connected(show_dialog):
        pressed.disconnect(show_dialog)