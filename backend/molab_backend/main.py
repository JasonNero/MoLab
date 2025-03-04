import asyncio
import logging
import uuid
from dataclasses import dataclass, field

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("backend")

@dataclass
class Connection:
    """Simple connection class to handle WebSocket connections.

    Args:
        websocket (WebSocket): The WebSocket connection for the worker or client.
        id (str): The unique identifier for the connection.
    """
    websocket: WebSocket
    id: str = field(default_factory=lambda: str(uuid.uuid4()))

class WorkerManager:
    """Worker manager class to manage worker connections using round-robin scheduling."""
    def __init__(self):
        self.workers: list[Connection] = []
        self.lock = asyncio.Lock()
        self.next_worker = 0

    async def register(self, websocket: WebSocket):
        """
        Register a new worker.

        Args:
            websocket (WebSocket): The WebSocket connection for the worker.

        Returns:
            Connection: The registered worker instance.
        """
        worker = Connection(websocket)
        async with self.lock:
            self.workers.append(worker)
            logger.info(
                f"Worker {worker.id} connected. Total workers: {len(self.workers)}"
            )
        return worker

    async def unregister(self, worker: Connection):
        """
        Unregister an existing worker.

        Args:
            worker (Connection): The worker instance to unregister.
        """
        async with self.lock:
            self.workers.remove(worker)
            logger.info(
                f"Worker {worker.id} disconnected. Total workers: {len(self.workers)}"
            )
            if len(self.workers) > 0:
                self.next_worker = self.next_worker % len(self.workers)

    async def get_next_worker(self):
        """
        Get the next available worker using round-robin scheduling.

        Returns:
            Connection: The next available worker instance.
        """
        async with self.lock:
            worker = self.workers[self.next_worker]
            self.next_worker = (self.next_worker + 1) % len(self.workers)
        return worker

class ClientManager:
    """Client manager class to manage client connections."""
    def __init__(self):
        self.clients: list[Connection] = []
        self.lock = asyncio.Lock()

    async def register(self, websocket: WebSocket):
        """
        Register a new client.

        Args:
            websocket (WebSocket): The WebSocket connection for the client.

        Returns:
            Connection: The registered client instance.
        """
        client = Connection(websocket)
        async with self.lock:
            self.clients.append(client)
            logger.info(
                f"Client {client.id} connected. Total clients: {len(self.clients)}"
            )
        return client

    async def unregister(self, client: Connection):
        """
        Unregister an existing client.

        Args:
            client (Connection): The client instance to unregister.
        """
        async with self.lock:
            self.clients.remove(client)
            logger.info(
                f"Client {client.id} disconnected. Total clients: {len(self.clients)}"
            )

worker_manager = WorkerManager()
client_manager = ClientManager()

app = FastAPI(title="Motion Inference Server")

async def handle_client_request(client: Connection, message: dict):
    """
    Handle client requests.

    Args:
        client (Connection): The client instance sending the request.
        message (dict): The message sent by the client.
    """
    if message["type"] == "infer":
        worker = await worker_manager.get_next_worker()
        await worker.websocket.send_json(message)
        result = await worker.websocket.receive_json()
        await client.websocket.send_json(result)
    else:
        logger.error(f"Client {client.id} sent unknown message:\n{message}")
        await client.websocket.send_text("Invalid message type")

@app.websocket("/register_worker")
async def register_worker(websocket: WebSocket):
    """
    WebSocket endpoint to register workers.

    Args:
        websocket (WebSocket): The WebSocket connection for the worker.
    """
    await websocket.accept()
    worker = await worker_manager.register(websocket)
    try:
        while True:
            # Ping/Keepalive
            await websocket.send_text("ping")
            await asyncio.sleep(5)
            # message = await websocket.receive_json()
            # await handle_worker_request(worker, message)
    except WebSocketDisconnect:
        await worker_manager.unregister(worker)

@app.websocket("/register_client")
async def register_client(websocket: WebSocket):
    """
    WebSocket endpoint to register clients.

    Args:
        websocket (WebSocket): The WebSocket connection for the client.
    """
    await websocket.accept()
    client = await client_manager.register(websocket)
    try:
        while True:
            message = await websocket.receive_json()
            await handle_client_request(client, message)
    except WebSocketDisconnect:
        await client_manager.unregister(client)

def main():
    """Main function to run the FastAPI app using Uvicorn."""
    # uvicorn.run(app, host="0.0.0.0", port=8000)
    uvicorn.run(app, host="127.0.0.1", port=8000)

if __name__ == "__main__":
    main()
