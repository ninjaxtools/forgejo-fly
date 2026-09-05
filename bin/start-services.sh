#!/bin/sh
set -eu

if [ -n "${DEBUGDEPLOY:-}" ]; then
    printf 'DEBUGDEPLOY is set; skipping startup and waiting indefinitely.\n' >&2
    exec sleep infinity
fi

/usr/local/bin/prepare-caddy.sh
/usr/local/bin/prepare-forgejo.sh
/usr/local/bin/initialize-forgejo.sh

exec /usr/local/bin/hivemind /etc/Procfile
