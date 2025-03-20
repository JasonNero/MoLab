class_name BackendWebSocket
extends Node

signal connected()
signal disconnected()
signal results_received(results: InferenceResults)

# The URL we will connect to.
@export var websocket_url = ""

# Our WebSocketClient instance.
var socket := WebSocketPeer.new()
var last_connected := false

var retry_delay := 4.0
var retry_max := 10
var retry_timer := 0.0
var retry_count := 0

func _ready():
	# TODO: This does not work in Web Export
	var host = OS.get_environment("GATEWAY_HOST")
	var port = OS.get_environment("GATEWAY_PORT")

	if host == "":
		host = "localhost"
	if port == "":
		port = "8000"

	websocket_url = "ws://" + host + ":" + port + "/register_client"
	print("Using Backend: ", websocket_url)

	socket.set_inbound_buffer_size(2**21)
	socket.set_outbound_buffer_size(2**21)
	socket.set_max_queued_packets(128)

func infer(infer_args: InferenceArgs):
	var message_dict = infer_args.to_dict()
	var text = JSON.stringify(message_dict)
	# Replace nan with NaN to avoid issues with JSON parsing later on
	text = text.replace("nan", "NaN")
	if OS.has_feature("debug"):
		print("Sending inference message to Backend:")
		print(text)
	socket.send_text(text)

func _connect():
	# Initiate connection to the given URL.
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	var err = socket.connect_to_url(websocket_url)
	retry_count += 1
	if err != OK:
		print("Invalid WebSocket URL")
		return

func _physics_process(_delta: float) -> void:
	socket.poll()

	var state = socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			print("Connecting to Backend ... (Retry {0}/{1})".format([retry_count, retry_max]))
		WebSocketPeer.STATE_OPEN:
			if not last_connected:
				print("Connected to Backend")
				last_connected = true
				retry_count = 0
				connected.emit()
			while socket.get_available_packet_count():
				var packet = socket.get_packet().get_string_from_utf8()
				results_received.emit(InferenceResults.from_json(packet))
		WebSocketPeer.STATE_CLOSED:
			if last_connected:
				var code = socket.get_close_code()
				var reason = socket.get_close_reason()
				print("Backend WebSocket closed with code: %d %s" % [code, reason])
				last_connected = false
				disconnected.emit()

			if retry_count >= retry_max:
				print("Backend WebSocket retry limit reached")
				set_physics_process(false)
			elif retry_timer <= 0.0:
				_connect()
				retry_timer = retry_delay
			else:
				retry_timer -= _delta
		_:
			print("Unhandled Backend WebSocket state: ", state)
