dsd: Docker Swarm in Docker
===========================

`dsd` is a small Bash script that helps create and manage a **local Docker Swarm cluster** using Docker-in-Docker containers.

It is shamelessly inspired by [k3d](https://k3d.io/), but for Docker Swarm instead of Kubernetes, with far fewer features and a lot of bugs.

The goal of this project is to provide a simple way to experiment with Docker Swarm locally without needing multiple machines.

This project was created to solve a personal need and has already fulfilled its purpose. Because of limited time, it is not actively maintained. New features will not be added and bugs may only be fixed if they affect my own workflow.


Requirements
------------

* Docker
* Bash

Docker must be installed and running on your system.


Usage
-----

```
./dsd.sh COMMAND [OPTIONS]
```

### Commands

| Command                   | Description                                      |
| ------------------------- | ------------------------------------------------ |
| `up [MANAGERS] [WORKERS]` | Create or scale the swarm cluster                |
| `down`                    | Destroy the swarm cluster                        |
| `stop`                    | Stop all swarm containers                        |
| `start`                   | Start previously stopped containers              |
| `ip [NODE]`               | Print the IP address of a node                   |
| `docker ...`              | Run Docker commands inside the main manager node |


Demostration
------------

### Cluster Initialization

Start a Docker Swarm cluster (inside Docker) with a single node:

```bash
./dsd.sh up
```

You can run Docker commands directly inside the main manager node using the helper command:

```bash
./dsd.sh docker node ls
```

However, since the Docker daemon port (`2375`) is published on the host as `12375`, it is usually more convenient to use your **local Docker client**.

#### Using `DOCKER_HOST`

You can connect your Docker client to the cluster using the `DOCKER_HOST` environment variable:

```bash
DOCKER_HOST=tcp://localhost:12375 docker node ls
```

To avoid repeating it in every command:

```bash
export DOCKER_HOST=tcp://localhost:12375
```

#### Using a Docker Context (recommended)

Another option is to create a Docker context:

```bash
docker context create dsd \
  --description "Docker Swarm in Docker" \
  --docker "host=tcp://localhost:12375"
```

Then run commands using the context:

```bash
docker --context dsd node ls
```

Or make it the default context:

```bash
docker context use dsd
```

### Running Services

Create an [overlay](https://docs.docker.com/engine/network/drivers/overlay/) network:

```bash
docker network create \
    --driver overlay \
    --attachable \
    custom_overlay_network
```

Deploy the [Traefik](https://github.com/traefik/traefik) stack:

```bash
docker stack deploy \
    --compose-file demo/traefik.yaml \
    stack-proxy
```

Access the Traefik dashboard at [http://localhost:18080/traefik](http://localhost:18080/traefik).

Deploy a simple [whoami](https://hub.docker.com/r/traefik/whoami) service:

```bash
docker stack deploy \
    --compose-file demo/whoami.yaml \
    stack-example
```

Verify that the service is running:

```bash
docker service ls
```

#### Testing the Service

You can check the service using a custom path prefix at [http://localhost:18080/whoami](http://localhost:18080/whoami), or by sending a request with `curl` using a custom host name:

```bash
curl \
    --header 'Host: whoami.swarm.localhost' \
    localhost:18080
```

You can also test the service from inside the swarm network.

Start a temporary Alpine container attached to the overlay network:

```bash
docker run --rm -it \
    --network custom_overlay_network \
    --name alpine \
    alpine
```

Inside the container:

```bash
ping whoami
```

or

```bash
wget -q -O - whoami
```

### Scaling the Cluster

Expand the cluster to **3 managers and 2 workers**:

```bash
./dsd.sh up 3 2
```

Add a constraint so the `whoami` service runs only on worker nodes:

```bash
docker service update \
  --constraint-add 'node.role==worker' \
  stack-example_whoami
```

Scale the service:

```bash
docker service scale stack-example_whoami=4
```

After these changes:

* Traefik should run on a **manager node**
* Four instances of the `whoami` service should run on **worker nodes**
* The dashboard and `curl` tests should continue working normally


Use Cases
---------

`dsd` is useful for:

* learning Docker Swarm
* testing swarm stacks locally
* experimenting with swarm networking
* testing service scheduling and scaling


Limitations
-----------

This project is intentionally simple and has several limitations:

* not production-grade
* minimal error handling
* limited configuration options
* designed primarily for **local experimentation**


Project Status
--------------

This project is provided as-is and is not actively maintained.
