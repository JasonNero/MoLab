# MoLab Deployment

Instead of running backend and worker locally, you can also deploy them using Docker:

```bash
docker-compose up
```

This command automatically sets up a container for the backend and worker components, setting up the Python environment (see the components `Dockerfile`s for details).
It then spins up the backend server as well as two worker instances connected via a bridge network.
Clients can then connect to the exposed port 8000.

Optionally, the Godot Frontend can be served as well, but only with reduced IO features.
For this, you need to build/export it as HTML first and uncomment the `frontend` segment of the `docker-compose.yaml` file.
