FROM debian:13-slim AS build-laminar

COPY build.sh /

RUN bash /build.sh

# Make tar package with only `laminarc` and dependencies
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y /opt/laminar_debian13_amd64.deb \
    && tar -cf /opt/laminarc.tar /usr/bin/laminarc \
    && for i in $(ldd /usr/bin/laminarc | grep '=> /' | awk '{print $3}'); do tar -rf /opt/laminarc.tar $i; done

# ----------------------------------------

FROM debian:13-slim AS get-docker

ARG DOCKER_VERSION
ENV DOCKER_VERSION=$DOCKER_VERSION

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y \
        curl

RUN DOCKER_ARCH="$(uname -m)" \
    && DOCKER_URL="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}" \
    && echo "${DOCKER_URL}" \
    && echo "${DOCKER_VERSION}" \
    && curl -kfsSL "${DOCKER_URL}/docker-${DOCKER_VERSION}.tgz" \
    | tar zxvf - --strip 1 -C /opt docker/docker

# ----------------------------------------

FROM debian:13-slim AS get-webhook

ENV WEBHOOK_VERSION="v1.21.0"
ENV WEBHOOK_ARCH="amd64"
ENV WEBHOOK_PACKAGE="webhookd-linux-${WEBHOOK_ARCH}.tgz"
ENV WEBHOOK_URI="https://github.com/ncarlier/webhookd/releases/download/${WEBHOOK_VERSION}/${WEBHOOK_PACKAGE}"

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y \
        curl

WORKDIR /opt

RUN curl --location --remote-name $WEBHOOK_URI \
    && mkdir webhook \
    && tar -xzf $WEBHOOK_PACKAGE -C webhook/ \
    && rm $WEBHOOK_PACKAGE

# ----------------------------------------

FROM debian:13-slim AS laminar

COPY --from=build-laminar /opt/laminar_debian13_amd64.deb /opt/laminar_debian13_amd64.deb
COPY --from=get-docker /opt/docker /usr/bin/docker

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y /opt/laminar_debian13_amd64.deb \
    && apt autoclean && apt clean && apt autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm /opt/*

# ----------------------------------------

FROM debian:13-slim AS webhook

COPY --from=build-laminar /opt/laminarc.tar /opt/laminarc.tar
COPY --from=get-webhook /opt/webhook/webhookd /usr/bin/webhookd

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y \
        jq \
    && apt autoclean && apt clean && apt autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && tar -xvf /opt/laminarc.tar -C / \
    && rm /opt/*
