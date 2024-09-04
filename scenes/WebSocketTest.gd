extends Node

# The URL we will connect to.
@export var websocket_url = "ws://127.0.0.1:8000/ws"

# Our WebSocketClient instance.
var socket = WebSocketPeer.new()

func _ready():
	print("Connecting to WebSocket URL: ", websocket_url)
	# socket.set_inbound_buffer_size(16777216)
	# socket.set_outbound_buffer_size(16777216)
	# socket.set_max_queued_packets(128)

	# Initiate connection to the given URL.
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Unable to connect")
		set_process(false)
	else:
		print("Connected successfully")
		# Wait for the socket to connect.
		await get_tree().create_timer(2).timeout

		# Send data.
		print("Sending data...")
		socket.send_text("{\"bvh_path\": \"sample/dummy.bvh\", \"text_prompt\": \"A dot goes where a go dots.\"}")

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
			print("Got data from server: ", socket.get_packet().get_string_from_utf8())

	# WebSocketPeer.STATE_CLOSING means the socket is closing.
	# It is important to keep polling for a clean close.
	elif state == WebSocketPeer.STATE_CLOSING:
		pass

	# WebSocketPeer.STATE_CLOSED means the connection has fully closed.
	# It is now safe to stop polling.
	elif state == WebSocketPeer.STATE_CLOSED:
		# The code will be -1 if the disconnection was not properly notified by the remote peer.
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d %s" % [code, reason])
		set_process(false) # Stop processing.
