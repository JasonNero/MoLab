extends MarginContainer

@onready var le_backend_uri: LineEdit = %LineEditBackend


var green = Color(0.213, 0.704, 0.337)
var red = Color(0.918, 0.368, 0.171)

func _ready() -> void:
	le_backend_uri.text_changed.connect(self.on_backend_uri_changed)
	Backend.connected.connect(self.on_backend_connected)
	Backend.disconnected.connect(self.on_backend_disconnected)

func on_backend_uri_changed(text: String) -> void:
	# Update the backend URI
	print("Backend URI changed to: ", text)
	Backend.websocket_url = text + "/register_client"
	Backend.set_physics_process(true)
	Backend._connect()

func on_backend_connected() -> void:
	le_backend_uri.add_theme_color_override("font_color", green)

func on_backend_disconnected() -> void:
	le_backend_uri.add_theme_color_override("font_color", red)
