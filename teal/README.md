# Teal

[Blue+Green](https://colorffy.com/color-scheme-generator?color=008080)

----------------------------------------

Proxy
-----

```bash
docker network create \
    --driver overlay \
    --attachable \
    teal_proxy
```

```bash
docker stack deploy \
    --compose-file teal/proxy.yaml \
    teal_proxy
```

----------------------------------------

Repository
----------

```bash
docker network create \
    --driver overlay \
    --attachable \
    teal_repo
```

```bash
docker stack deploy \
    --compose-file teal/repo.yaml \
    teal_repo
```

```bash
# TODO
ssh -q soft-admin user create juan && \
ssh -q soft-admin user add-pubkey juan 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtoO15w6tG1unNdimNU5uNZm7I3EymdpYO/twa8n9vO' && \
ssh -q soft repo create pepe && \
git push -f -u origin master
```

----------------------------------------

Registry
--------

```bash
docker network create \
    --driver overlay \
    --attachable \
    teal_registry
```

```bash
docker stack deploy \
    --compose-file teal/registry.yaml \
    teal_registry
```

### Test

```bash
docker run --rm -it \
    --privileged \
    --network teal_registry \
    --name dummy \
    docker:dind \
    --insecure-registry distribution:5000
```

```bash
docker exec -it dummy sh
```

```bash
docker pull alpine
docker image tag alpine distribution:5000/myimage
docker push distribution:5000/myimage
docker pull distribution:5000/myimage
```

----------------------------------------

### Test

Custom with busybox

```bash
docker run -it --rm -p 80:80 busybox
```

```bash
busybox httpd -f -h /var/www
```

Pre-build (https://github.com/kilna/envhttpd)

```bash
docker run --rm -e FOO=BAR -e YO=BRO -p 80:8111 kilna/envhttpd
```

### In Swarm

```bash
docker network create \
    --driver overlay \
    --attachable \
    teal_test_hello
```

```bash
docker stack deploy \
    --compose-file teal/hello_1.yaml \
    teal_web
```

```bash
docker stack deploy \
    --compose-file teal/hello_2.yaml \
    teal_web
```

Check from inside

```bash
docker run --rm -it \
    --network teal_proxy \
    --network teal_test_hello \
    --name alpine \
    alpine
```

----------------------------------------

Internal Proxy
--------------

### Option #1 - UNIX Sockets

- [Info #2](https://github.com/moby/moby/issues/32299#issuecomment-1996146337)
- [Info #1](https://forums.docker.com/t/host-docker-internal-in-production-environment/137507/4)

```bash
docker stack deploy \
    --compose-file teal/test_proxy_01.yaml \
    test_proxy1
```

```bash
wget -q -O - localhost:8081/?env=true
```

### [Option #2 - PROXY](https://github.com/moby/moby/issues/32299#issuecomment-1974967100)

- [tinyproxy](https://github.com/kalaksi/docker-tinyproxy)
- [3proxy](https://github.com/tarampampam/3proxy-docker)
- [HAProxy](https://github.com/Tecnativa/docker-tcp-proxy)

```bash
docker stack deploy \
    --compose-file teal/test_proxy_02.yaml \
    test_proxy2
```

```bash
wget -q -O - localhost:8082/?env=true
```

### [Option #3 - iptables](https://github.com/moby/moby/issues/32299#issuecomment-1974967100)

Proof of concept

```bash
docker stack deploy \
    --compose-file teal/test_proxy_03.yaml \
    test_proxy3
```

```bash
docker exec -it $(docker ps | grep iptables | cut -d' ' -f1) sh
```

```bash
apk update
apk add --no-cache socat iptables
```

```bash
LISTEN_IP=$(ip route | grep default | awk '{print $3}')
iptables -A INPUT -p tcp -s $LISTEN_IP --dport 8083 -j ACCEPT
iptables -A INPUT -p tcp --dport 8083 -j REJECT # for internet exposed port use 'DROP'
socat -dd TCP-LISTEN:8083,fork TCP:whoami:8083
```

```bash
wget -q -O - localhost:8083/?env=true
```

### Option #3 - Traefik

TO RESEARCH

Create entry point in traefil

    entryPoints:
     internal:
       address: ":8081"

Bind and filter (`mode: host` + iptables)

Use the entry point

    - "traefik.http.routers.my-service.entrypoints=internal"

Create a white list middleware?

    - "traefik.http.middlewares.internal-only.ipwhitelist.sourcerange=10.0.0.0/8,192.168.0.0/16,127.0.0.1/32"

### Swarm Hosts

As a security measure, use `iptables` on the hosts to drop any incoming request from outside of the Swarm network.

```bash
# Allow only traffic from loopback (localhost)
sudo iptables -t mangle -I PREROUTING ! -i lo -p tcp --dport 8081 -j DROP
```

----------------------------------------
