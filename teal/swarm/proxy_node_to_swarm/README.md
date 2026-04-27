Internal Proxy
--------------

### Option #1 - UNIX Sockets

- [Info #1](https://forums.docker.com/t/host-docker-internal-in-production-environment/137507/4)
- [Info #2](https://github.com/moby/moby/issues/32299#issuecomment-1996146337)

```bash
docker stack deploy \
    --detach=false \
    --compose-file proxy_01.yaml \
    test_proxy1
```

```bash
wget -q -O - localhost:8081/?env=true
```

### Option #2 - PROXY

- [Info](https://github.com/moby/moby/issues/32299#issuecomment-1974967100)
- [tinyproxy](https://github.com/kalaksi/docker-tinyproxy)
- [3proxy](https://github.com/tarampampam/3proxy-docker)
- [HAProxy](https://github.com/Tecnativa/docker-tcp-proxy)

```bash
docker stack deploy \
    --detach=false \
    --compose-file proxy_02.yaml \
    test_proxy2
```

```bash
wget -q -O - localhost:8082/?env=true
```

### Option #3 - iptables

- [Info](https://github.com/moby/moby/issues/32299#issuecomment-1974967100)

```bash
docker stack deploy \
    --detach=false \
    --compose-file proxy_03.yaml \
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

### Swarm Hosts

As a security measure, use `iptables` on the hosts to drop any incoming request from outside of the Swarm network.

```bash
# Allow only traffic from loopback (localhost)
sudo iptables -t mangle -I PREROUTING ! -i lo -p tcp --dport 8081 -j DROP
```
