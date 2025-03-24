import asyncio
import logging
import os
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
        self.request_queue = asyncio.Queue()

    async def register(self, websocket: WebSocket) -> Connection:
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

    async def get_next_worker(self) -> Connection:
        """
        Get the next available worker using round-robin scheduling.

        Returns:
            Connection: The next available worker instance.
        """
        async with self.lock:
            worker = self.workers[self.next_worker]
            self.next_worker = (self.next_worker + 1) % len(self.workers)
        return worker

    async def process_requests(self):
        while True:
            client, message = await self.request_queue.get()
            worker = await self.get_next_worker()
            await worker.websocket.send_json(message)
            result = await worker.websocket.receive_json()
            await client.websocket.send_json(result)
            self.request_queue.task_done()


class ClientManager:
    """Client manager class to manage client connections."""

    def __init__(self):
        self.clients: list[Connection] = []
        self.lock = asyncio.Lock()

    async def register(self, websocket: WebSocket) -> Connection:
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
        await worker_manager.request_queue.put((client, message))
    else:
        logger.error(f"Client {client.id} sent unknown message:\n{message}")
        await client.websocket.send_text("Invalid message type")


@app.on_event("startup")
async def startup_event():
    asyncio.create_task(worker_manager.process_requests())


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
            # Ping/Keepalive done by uvicorn
            await asyncio.sleep(5)
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
    host = os.getenv("MOLAB_GATEWAY_HOST", "localhost")
    port = int(os.getenv("MOLAB_GATEWAY_PORT", 8000))
    logger.info(f"Running server at http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, ws_ping_interval=30, ws_ping_timeout=240)


if __name__ == "__main__":
    main()
