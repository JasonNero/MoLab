from qtpy.QtCore import QObject, QUrl, Signal
from qtpy.QtWebSockets import QWebSocket

import json


class MoLabQClient(QObject):
    """
    A client for interacting with the MoLab backend for motion inference using Qt's QWebSocket.
    """
    inference_received = Signal(dict)
    connected = Signal()

    def __init__(self, backend_uri="ws://localhost:8000"):
        """
        Initializes the MoLabQClient with the given backend URI.

        Args:
            backend_uri (str): The URI of the MoLab backend server.
        """
        super().__init__()
        self.backend_uri = backend_uri
        self.websocket = QWebSocket()
        self.websocket.connected.connect(self.connected.emit)
        self.websocket.textMessageReceived.connect(self.on_message_received)

    def open(self):
        """
        Opens the WebSocket connection to the backend.
        """
        print("Connecting ...")
        self.websocket.open(QUrl(f"{self.backend_uri}/register_client"))

    def close(self):
        """
        Closes the WebSocket connection.
        """
        print("Closing ...")
        self.websocket.close()

    def infer(self, inference_args):
        """
        Sends an inference request to the backend.

        Args:
            inference_args (dict): The data to be sent for inference.
        """
        print("Sending inference request ...")
        inference_args["type"] = "infer"
        self.websocket.sendTextMessage(json.dumps(inference_args))

    def on_message_received(self, message):
        """
        Slot called when a message is received from the WebSocket.
        Emits the inference_received signal with the result.

        Args:
            message (str): The message received from the backend.
        """
        result = json.loads(message)
        print("Received Result!")
        self.inference_received.emit(result)
