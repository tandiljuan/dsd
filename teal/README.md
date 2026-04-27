# Teal: Swarm Cluster Demo

> [Teal Color](https://colorffy.com/color-scheme-generator?color=008080)

## Introduction

This tutorial walks through building a complete, self-contained Docker Swarm environment for local development and experimentation. Using a cluster created with the `dsd` script, you will deploy and connect several real-world components.

The goal is to provide a practical, end-to-end example of how services interact inside a Docker Swarm cluster.

This setup is intentionally simplified and designed for learning purposes.

Before starting, make sure:

* Docker is installed and running
* you have already completed the main `dsd` README tutorial
* you are running commands from the directory containing this README

---

## Swarm Cluster

Start by creating a Docker Swarm cluster with the following command.

```bash
../dsd.sh up -p 12375:2375 -p 18080:80 -p 10022:23231 -e '--insecure-registry localhost:5000' 1 3
```

The main difference compared to the cluster in the main README is that here we expose an additional port to access the local Git server (hosted inside the swarm cluster), and we pass a parameter to allow an insecure local registry that we will also host.

---

## Application Proxy

In this section we will run [traefik](https://github.com/traefik/traefik) as our reverse proxy.

### Network

Create the network where the proxy will run.

```bash
docker network create \
    --driver overlay \
    --attachable \
    teal_proxy
```

Note: If the network already exists, Docker will return an error. You can safely ignore it if you are re-running the tutorial.

### Deploy

Deploy the proxy.

```bash
docker stack deploy \
    --detach=false \
    --compose-file swarm/proxy.yaml \
    teal_proxy
```

### Dashboard

Once the deployment finishes, you can access Traefik's dashboard at [http://CHANGE_WITH_YOUR_HOST:18080/traefik](http://CHANGE_WITH_YOUR_HOST:18080/traefik).

![traefik's dashboard](./assets/traefik.png)

If the dashboard does not load, wait a few seconds and refresh the page. Services may take a short time to become available.
