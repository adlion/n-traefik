#!/bin/sh
# source <(sed 's/^/export /' .env)
export $(grep -v '^#' /etc/traefik/traefik.env | xargs -0)

rm -f /etc/traefik/jit-traefik.env

exec "$@"
