#!/bin/sh

# Load variables from a file without overwriting existing ones
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    [ -z "$key" ] && continue
    [ "${key#\#}" != "$key" ] && continue
    # Only set the variable if it's not already defined
    [ -z "$(printenv "$key")" ] && export "$key=$value"
done < ./config.env

envsubst < /app/index.html > /var/www/index.html

darkhttpd /var/www
