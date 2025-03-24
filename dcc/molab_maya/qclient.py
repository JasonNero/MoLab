from qtpy.QtCore import QObject, QUrl, Signal
from qtpy.QtWebSockets import QWebSocket
from qtpy.QtNetwork import QAbstractSocket

import json
import os


class MoLabQClient(QObject):
    """
    A client for interacting with the MoLab backend for motion inference using Qt's QWebSocket.
    """
    inference_received = Signal(dict)
    connected = Signal()
    disconnected = Signal()

    def __init__(self, backend_uri=""):
        """
        Initializes the MoLabQClient with the given backend URI.

        Args:
            backend_uri (str): The URI of the MoLab backend server.
        """
        super().__init__()
        if backend_uri:
            self.backend_uri = backend_uri
        else:
            host = os.getenv("MOLAB_GATEWAY_HOST", "localhost")
            port = os.getenv("MOLAB_GATEWAY_PORT", "8000")
            self.backend_uri = f"ws://{host}:{port}"
        self.websocket = QWebSocket()
        self.websocket.disconnected.connect(self.disconnected.emit)
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

    def is_connected(self):
        return self.websocket.state() == QAbstractSocket.SocketState.ConnectedState

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
