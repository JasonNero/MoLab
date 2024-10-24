class_name DCCWebSocket
extends Node

# The URL we will connect to.
@export var websocket_url = "ws://127.0.0.1:8000/dcc"

# Our WebSocketClient instance.
var socket = WebSocketPeer.new()
var timeout_ms = 4000  # 4s

func _ready():
	set_process(false)
	print("Connecting to DCC WebSocket URL: ", websocket_url)
	socket.set_inbound_buffer_size(2**21)
	socket.set_outbound_buffer_size(2**21)
	socket.set_max_queued_packets(128)

	# Initiate connection to the given URL.
	var start_time = Time.get_ticks_msec()
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Invalid WebSocket URL")
		set_process(false)
		return

	while socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		socket.poll()
		if Time.get_ticks_msec() - start_time > timeout_ms:
			print("Connection to Backend WebSocket timed out.")
			set_process(false)
			return
		await get_tree().process_frame

	print("Connection established to Backend WebSocket.")
	set_process(true)

func _process(_delta):
	# Call this in _process or _physics_process. Data transfer and state updates
	# will only happen when calling this function.
	socket.poll()

	# get_ready_state() tells you what state the socket is in.
	var state = socket.get_ready_state()

	# WebSocketPeer.STATE_OPEN means the socket is connected and ready
	# to send and receive data.
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			print("Got data from DCC:\n", socket.get_packet().get_string_from_utf8())

	# WebSocketPeer.STATE_CLOSED means the connection has fully closed.
	# It is now safe to stop polling.
	elif state == WebSocketPeer.STATE_CLOSED:
		# The code will be -1 if the disconnection was not properly notified by the remote peer.
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("DCC WebSocket closed with code: %d %s" % [code, reason])
		set_process(false) # Stop processing.

	else:
		print("DCC WebSocket state: ", state)
