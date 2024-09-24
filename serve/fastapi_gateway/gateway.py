import asyncio
import logging
from typing import Dict

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

# Dataclasses for inference arguments and results, move to a shared file
# from serve.inference_worker import InferenceArgs, InferenceResults

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("gateway")


class Worker:
    """Simple worker class."""
    def __init__(self, websocket: WebSocket):
        self.websocket = websocket
        self.id = id(websocket)


class WorkerManager:
    """Simple round-robin worker manager."""
    def __init__(self):
        self.workers: list[Worker] = []
        self.lock = asyncio.Lock()
        self.next_worker = 0

    async def register(self, websocket: WebSocket):
        worker = Worker(websocket)
        async with self.lock:
            self.workers.append(worker)
            logger.info(f"Worker {worker.id} connected. Total workers: {len(self.workers)}")
        return worker

    async def unregister(self, worker: Worker):
        async with self.lock:
            self.workers.remove(worker)
            logger.info(
                f"Worker {worker.id} disconnected. Total workers: {len(self.workers)}"
            )
            if len(self.workers) > 0:
                self.next_worker = self.next_worker % len(self.workers)

    async def get_next_worker(self):
        async with self.lock:
            worker = self.workers[self.next_worker]
            self.next_worker = (self.next_worker + 1) % len(self.workers)
        return worker


class Client:
    """Simple client class."""
    def __init__(self, websocket: WebSocket):
        self.websocket = websocket
        self.id = id(websocket)


class ClientManager:
    """Simple client manager."""
    def __init__(self):
        self.clients: list[Client] = []
        self.lock = asyncio.Lock()

    async def register(self, websocket: WebSocket):
        async with self.lock:
            client = Client(websocket)
            self.clients.append(client)
            logger.info(f"Client {client.id} connected. Total clients: {len(self.clients)}")
        return client

    async def unregister(self, client: Client):
        async with self.lock:
            self.clients.remove(client)
            logger.info(f"Client {client.id} disconnected. Total clients: {len(self.clients)}")


worker_manager = WorkerManager()
client_manager = ClientManager()

app = FastAPI(title="Motion Inference Server")


async def handle_client_request(client: Client, message: dict):
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
    await websocket.accept()
    client = await client_manager.register(websocket)
    try:
        while True:
            message = await websocket.receive_json()
            await handle_client_request(client, message)
    except WebSocketDisconnect:
        await client_manager.unregister(client)


if __name__ == "__main__":
    # uvicorn.run(app, host="0.0.0.0", port=8000)
    uvicorn.run(app, host="127.0.0.1", port=8000)
