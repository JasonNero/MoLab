# Deployment Guide

If you want to deploy MoLab in a production environment, you can follow the instructions below to set up the backend and worker components on a server.
How you distribute the clients is up to you.

## Option 1: Bare Metal

Let's assume we want to run the worker and backend on the same server for now, which is the simplest setup, because we can just follow the regular installation guide.
In a second step we'll add more workers on different servers.

On the first server, clone the repository and make sure you have the necessary dependencies installed (uv and just).
Then setup the Python environment and download the model weights:

```console
just install
just download
```

You can then run the backend and worker components on the server:

```console
just run-backend
just run-worker
```

By default, the backend server will listen on `0.0.0.0:8000`, which means it will accept connections from any IP address.

### Adding More Workers

Now, let's add another worker on a different server.
Make sure you have the repository cloned and setup as before.

By default, a worker will connect to the backend server running on `localhost:8000`.
If you want to change this behavior, you can set the `MOLAB_GATEWAY_HOST` and `MOLAB_GATEWAY_PORT` environment variables accordingly:

```console
export MOLAB_GATEWAY_HOST=your-host
export MOLAB_GATEWAY_PORT=your-port
```

Then you can start the worker:

```console
just run-worker
```

You should see a message that the worker has connected to the backend server, which means it is ready to accept inference requests.

For easier deployment, you can also use Docker, which we'll cover in the next section.

## Option 2: Docker

Each component has a `Dockerfile` in its root directory, which follows a similar setup as the bare metal setup, but with the added benefit of containerization.

### Gateway Image

To build the backend image, you can run the following command:

```console
cd backend
docker build -t molab_backend:latest .
```

Then export the image to a tar file and transfer it to your server:

```console
docker save -o molab_backend.tar molab_backend:latest
```

On the server, load the image and start the container:

```console
docker load -i molab_backend.tar
docker run -p 8000:8000 molab_backend
```

This will start the backend server and expose it on port 8000.

### Worker Image

If you haven't done so already, make download the model weights:

```console
just download
```

Now you can follow the same steps as above, but for the worker component:

```console
cd models/condmdi
docker build -t molab_worker:latest .
```

Then export the image to a tar file and transfer it to your server:

```console
docker save -o molab_worker.tar molab_worker:latest
```

On the server, load the image and start the container, this time with the necessary environment variables pointing to the backend server:

```console
docker load -i molab_worker.tar
docker run molab_worker \
-e MOLAB_GATEWAY_HOST=your-host \
-e MOLAB_GATEWAY_PORT=your-port
```

### `docker-compose`

As an alternative approach to the steps outline above, you can also use `docker-compose`.

There is a `docker-compose.yml` file in the root directory as example that you can use to start the backend and two worker instances locally.
It specifies the necessary environment variables for the backend and workers, as well as the GPU requirement for the workers.

```console
docker-compose up
```
