class_name BackendWebSocket
extends Node

signal results_received(results: InferenceResults)

# The URL we will connect to.
@export var websocket_url = "ws://127.0.0.1:8000/register_client"

# Our WebSocketClient instance.
var socket := WebSocketPeer.new()
var timeout_ms := 4000  # 4s
var _connected := false

func _ready():
	set_physics_process(false)
	socket.set_inbound_buffer_size(2**21)
	socket.set_outbound_buffer_size(2**21)
	socket.set_max_queued_packets(128)

	# Using physics_process here to limit the polling frequency
	set_physics_process(true)

func infer(infer_args: InferenceArgs):
	var message_dict = infer_args.to_dict()
	var text = JSON.stringify(message_dict)
	# Replace nan with NaN to avoid issues with JSON parsing later on
	text = text.replace("nan", "NaN")
	print(text)
	socket.send_text(text)

func _connect():
	# Initiate connection to the given URL.
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Invalid WebSocket URL")
		return

func _physics_process(_delta: float) -> void:
	socket.poll()

	var state = socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			print("Connecting to Backend ...")
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				print("Connected to Backend")
				_connected = true
			while socket.get_available_packet_count():
				var packet = socket.get_packet().get_string_from_utf8()
				results_received.emit(InferenceResults.from_json(packet))
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				var code = socket.get_close_code()
				var reason = socket.get_close_reason()
				print("Backend WebSocket closed with code: %d %s" % [code, reason])
				_connected = false
			_connect()
		_:
			print("Unhandled Backend WebSocket state: ", state)
