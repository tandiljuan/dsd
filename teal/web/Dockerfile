FROM alpine

RUN apk update \
    && apk add --no-cache \
        darkhttpd \
        gettext-envsubst \
    && rm -rf /var/cache/apk/*

WORKDIR /app

COPY . /app

CMD ["sh", "start.sh"]
