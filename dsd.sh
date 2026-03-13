#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# dsd - Docker Swarm in Docker
# Copyright (C) 2026 Juan Manuel Lopez
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

NAME_IMAGE='docker:dind'
NAME_SWARM_NET='swarm_net'

PREFIX_MANAGER='manager'
PREFIX_WORKER='worker'

# -------------------------------------
# Download Image.
#
# Download a Docker image if it is not already present locally.
# If the image exists, the download step is skipped.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Docker image name
#
# Returns:
#   Prints status messages indicating whether the image was downloaded
#   or already available.
# -------------------------------------
image_download () {
    local image_name="${1}"
    local image_id=$(docker image ls --quiet --filter "reference=${image_name}")
    if [[ -z "${image_id}" ]]; then
        echo "> Download image '${image_name}'"
        docker pull "${image_name}"
        if (( $? > 0 )); then
            echo "> Failed to download image '${image_name}'"
            exit 1
        fi
        image_id=$(docker image ls --quiet --filter "reference=${image_name}")
    fi
    echo "> Image '${image_name}' (${image_id}) ready"
}

# -------------------------------------
# Network Creation.
#
# Create a Docker network if it does not already exist.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Network name
#
# Returns:
#   Prints the created or existing network identifier.
# -------------------------------------
network_up () {
    local net_name="${1}"
    local net_id=$(docker network ls --quiet --filter "name=${net_name}")
    if [[ -z "${net_id}" ]]; then
        net_id=$(docker network create --driver bridge "${net_name}" | cut -c 1-12)
    fi
    echo "> Created '${net_name}' network (${net_id})"
}

# -------------------------------------
# Network Destroy.
#
# Remove a Docker network.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Network name
#
# Returns:
#   Prints confirmation that the network was removed.
# -------------------------------------
network_down () {
    local net_name="${1}"
    docker network rm "${net_name}" &> /dev/null
    echo "> Removed '${net_name}' network"
}

# -------------------------------------
# Start a Container.
#
# Create a container if it does not exist, or start it if it already
# exists but is not currently running. The container is attached to
# the swarm network and configured to run Docker-in-Docker.
#
# Globals:
#   NAME_SWARM_NET
#   NAME_IMAGE
#   PREFIX_MANAGER
#
# Arguments:
#   $1 - Container name
#
# Returns:
#   Prints container status and waits until the Docker daemon inside
#   the container becomes available.
# -------------------------------------
container_up () {
    local name="${1}"
    local node_id=$(docker ps --all --filter "name=${name}" --quiet)
    local status=$(docker inspect --format '{{.State.Status}}' "${name}" 2>/dev/null | tr -cd '[:alnum:]')

    if [[ -n "${node_id}" ]] && [[ 'running' != "${status}" ]]; then
        docker start "${name}" &> /dev/null
    fi

    if [[ -z "${node_id}" ]]; then
        local publish=''
        if [[ "${name}" == "${PREFIX_MANAGER}1" ]]; then
            publish='--publish 12375:2375 --publish 10080:80'
        fi
        node_id=$(
            docker run \
            --detach \
            --privileged \
            --network "${NAME_SWARM_NET}" $publish \
            --env DOCKER_TLS_CERTDIR='' \
            --env DOCKER_HOST='tcp://0.0.0.0:2375' \
            --hostname "${name}" \
            --name "${name}" \
            "${NAME_IMAGE}" | cut -c 1-12
        )
    fi

    echo "> [${name}] Container started (${node_id})"

    echo -n "> [${name}] "
    local waiting=false
    until docker exec "${name}" docker info &>/dev/null; do
        waiting=true
        echo -n '.'
        sleep 1
    done

    if [[ $waiting == true ]]; then
        echo
        echo -n "> [${name}] "
    fi

    echo "Docker service (in container) is ready!"
}

# -------------------------------------
# Container IP.
#
# Retrieve the IP address of a container within the swarm network.
#
# Globals:
#   NAME_SWARM_NET
#
# Arguments:
#   $1 - Container name
#
# Returns:
#   The container IP address.
# -------------------------------------
container_ip () {
    local name="${1}"
    docker inspect -f "{{.NetworkSettings.Networks.${NAME_SWARM_NET}.IPAddress}}" "${name}"
}

# -------------------------------------
# Start a Node.
#
# Create or start a container node and join it to the Docker Swarm
# cluster if it is not already part of the swarm.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Node name prefix
#   $2 - Node index
#   $3 - Manager IP address
#   $4 - Swarm join token
#
# Returns:
#   Prints the swarm state of the node and status messages describing
#   the join process.
# -------------------------------------
node_up () {
    local name="${1}${2}"
    container_up "${name}"
    local state=$(swarm_state "${name}")
    echo "> [${name}] Swarm state: '${state}'"
    if [[ 'inactive' == "${state}" ]]; then
        docker exec "${name}" sh -c "docker swarm join --token ${4} ${3}:2377" &> /dev/null
        echo "> [${name}] Swarm initialized"
    fi
}

# -------------------------------------
# Remove a Node.
#
# Remove a node from the Docker Swarm cluster and delete the
# corresponding container.
#
# If the node is a manager, it is first demoted before removal.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Node name prefix
#   $2 - Node index
#   $3 - Main manager container name
#
# Returns:
#   Prints status messages indicating whether the node was removed
#   from the swarm and whether the container was deleted.
# -------------------------------------
node_down () {
    local name="${1}${2}"
    local manager_status=$(docker inspect --format '{{.State.Status}}' "${3}" 2>/dev/null | tr -cd '[:alnum:]')
    if [[ "${name}" != "${3}" ]] && [[ 'running' == "${manager_status}" ]]; then
        local node_id=$(docker exec "${3}" sh -c "docker node ls --quiet --filter 'name=${name}'")
        if [[ -n "${node_id}" ]]; then
            local node_role=$(docker exec "${3}" sh -c "docker node inspect --format '{{ .Spec.Role }}' ${name}")
            if [[ 'manager' == "${node_role}" ]]; then
                docker exec "${3}" sh -c "docker node demote ${name}" &> /dev/null
            fi
            docker exec "${3}" sh -c "docker node rm --force ${node_id}" &> /dev/null
            echo "> [${name}] Node removed from the Swarm (${node_id})"
        fi
    fi
    docker rm -f "${name}" &> /dev/null
    echo "> [${name}] Container removed"
}

# -------------------------------------
# Downgrade Nodes.
#
# Reduce the number of running nodes with a given prefix to the
# specified target amount by removing excess nodes.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Node name prefix
#   $2 - Target number of nodes
#   $3 - Manager container name
#
# Returns:
#   Removes nodes until the desired count is reached.
# -------------------------------------
node_downgrade () {
    local prefix="${1}"
    local from=$(docker ps --all --filter "name=${prefix}+" --quiet | wc -l)
    local to=${2:-0}
    local manager="${3}"

    for i in $(seq $from -1 $to | head -n -1); do
        node_down $prefix $i $manager
    done
}

# -------------------------------------
# Swarm State of Node.
#
# Retrieve the Docker Swarm state of a given node.
#
# Globals:
#   None
#
# Arguments:
#   $1 - Node name
#
# Returns:
#   The local swarm state of the node (for example: active or inactive).
# -------------------------------------
swarm_state () {
    docker exec "${1}" sh -c "docker info --format '{{.Swarm.LocalNodeState}}'"
}

# -------------------------------------
# Action Up.
#
# Create and initialize a Docker Swarm cluster using Docker-in-Docker
# containers. This includes downloading the required image, creating
# the swarm network, initializing the first manager node, and creating
# additional manager and worker nodes as requested.
#
# Globals:
#   NAME_IMAGE
#   NAME_SWARM_NET
#   PREFIX_MANAGER
#   PREFIX_WORKER
#
# Arguments:
#   $1 - Desired number of manager nodes (default: 1)
#   $2 - Desired number of worker nodes (default: 0)
#
# Returns:
#   Prints cluster creation progress and displays the swarm node list
#   when the cluster is ready.
# -------------------------------------
action_up () {
    local managers_amount=${1:-1}
    local workers_amount=${2:-0}

    if (( $managers_amount <= 0 )); then
        echo "> The amount of managers must be equal or greater than 1"
        exit 1
    fi

    if (( $workers_amount < 0 )); then
        echo "> The amount of workers must be equal or greater than 0"
        exit 1
    fi

    # Download Docker-in-Docker image
    image_download "${NAME_IMAGE}"

    # Create network
    network_up "${NAME_SWARM_NET}"

    # Create main manager node
    local manager_name="${PREFIX_MANAGER}1"
    container_up "${manager_name}"

    # Setup Swarm
    local manager_ip=$(container_ip "${manager_name}")
    echo "> [${manager_name}] IP: '${manager_ip}'"
    local manager_swarm_state=$(swarm_state "${manager_name}")
    echo "> [${manager_name}] Swarm state: '${manager_swarm_state}'"

    if [[ 'inactive' == "${manager_swarm_state}" ]]; then
        docker exec "${manager_name}" sh -c "docker swarm init --advertise-addr ${manager_ip}" &> /dev/null
        echo "> [${manager_name}] Swarm initialized"
    fi

    local token_manager=$(docker exec "${manager_name}" sh -c 'docker swarm join-token -q manager')
    local token_worker=$(docker exec "${manager_name}" sh -c 'docker swarm join-token -q worker')

    # Downgrade workers
    node_downgrade $PREFIX_WORKER $workers_amount $manager_name

    # Downgrade managers
    node_downgrade $PREFIX_MANAGER $managers_amount $manager_name

    # Create managers
    for i in $(seq 2 "${managers_amount}"); do
        node_up $PREFIX_MANAGER $i $manager_ip $token_manager
    done

    # Create workers
    for i in $(seq 1 "${workers_amount}"); do
        node_up $PREFIX_WORKER $i $manager_ip $token_worker
    done

    echo
    docker exec "${manager_name}" sh -c 'docker node ls'
}

# -------------------------------------
# Action Down.
#
# Destroy the Docker Swarm cluster by removing all worker and manager
# nodes and deleting the swarm network.
#
# Globals:
#   NAME_SWARM_NET
#   PREFIX_MANAGER
#   PREFIX_WORKER
#
# Arguments:
#   None
#
# Returns:
#   Prints status messages describing the cluster teardown process.
# -------------------------------------
action_down () {
    local manager_name="${PREFIX_MANAGER}1"

    # Downgrade workers
    node_downgrade $PREFIX_WORKER 0 $manager_name

    # Downgrade managers
    node_downgrade $PREFIX_MANAGER 0 $manager_name

    # Remove network
    network_down "${NAME_SWARM_NET}"
}

# -------------------------------------
# Action Stop.
#
# Stop all running containers that belong to the swarm cluster.
#
# Globals:
#   PREFIX_MANAGER
#   PREFIX_WORKER
#
# Arguments:
#   None
#
# Returns:
#   Prints the names of containers that were stopped.
# -------------------------------------
action_stop () {
    local workers=$(docker ps --filter "name=${PREFIX_WORKER}+" --format '{{ .Names }}' | sort --reverse)
    local managers=$(docker ps --filter "name=${PREFIX_MANAGER}+" --format '{{ .Names }}' | sort --reverse)
    local list="${workers} ${managers}"

    for i in ${list}; do
        docker stop "${i}" &> /dev/null
        echo "> [${i}] Stopped"
    done
}

# -------------------------------------
# Action Start.
#
# Start previously created swarm containers that are currently stopped.
#
# Globals:
#   PREFIX_MANAGER
#   PREFIX_WORKER
#
# Arguments:
#   None
#
# Returns:
#   Prints the names of containers that were started.
# -------------------------------------
action_start () {
    local workers=$(docker ps --all --filter "name=${PREFIX_WORKER}+" --format '{{ .Names }}' | sort)
    local managers=$(docker ps --all --filter "name=${PREFIX_MANAGER}+" --format '{{ .Names }}' | sort)
    local list="${managers} ${workers}"

    for i in ${list}; do
        local status=$(docker inspect --format '{{.State.Status}}' "${i}" 2>/dev/null | tr -cd '[:alnum:]')
        if [[ 'exited' == "${status}" ]]; then
            docker start "${i}" &> /dev/null
            echo "> [${i}] Started"
        fi
    done
}

# -------------------------------------
# Action Help.
#
# Display usage information and available commands for the script.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   Prints help text describing the script and its commands.
# -------------------------------------
action_help () {
    cat <<EOF
dsd: Docker Swarm in Docker

This is a simple (and limited) Bash script that helps create and manage a local
Docker Swarm cluster using Docker-in-Docker.

It is shamelessly inspired by [k3d](https://k3d.io/), but for Docker Swarm
instead of Kubernetes, with far fewer features and a lot of bugs.

Commands:

up [MANAGERS] [WORKERS]    Create a swarm network and cluster with the
                           specified number of nodes. Defaults: 1 manager and 0
                           workers.
down                       Remove the swarm cluster and its network.
stop                       Stop all nodes in the running swarm cluster.
start                      Start a previously stopped swarm cluster.
ip [NODE]                  Return the IP of the specified node. The
                           default value is the main manager.
docker                     Run Docker commands in the main manager node.
EOF
}

# -------------------------------------
# Handle Script Commands
# -------------------------------------
case "${1}" in
    "up")
        echo "> # CREATE SWARM CLUSTER"
        action_up ${2:-1} ${3:-0}
        ;;
    "down")
        echo "> # DESTROY SWARM CLUSTER"
        action_down
        ;;
    "stop")
        echo "> # STOP SWARM CLUSTER"
        action_stop
        ;;
    "start")
        echo "> # START SWARM CLUSTER"
        action_start
        ;;
    "ip")
        container_ip "${2:-${PREFIX_MANAGER}1}"
        ;;
    "docker")
        docker exec -it "${PREFIX_MANAGER}1" docker ${@:2}
        ;;
    *)
        action_help
        ;;
esac
