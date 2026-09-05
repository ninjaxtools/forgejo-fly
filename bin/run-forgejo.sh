#!/bin/sh
set -eu

/usr/local/bin/prepare-forgejo.sh
exec su forgejo -s /bin/sh -c "exec /usr/local/bin/forgejo -c \"$GITEA_APP_INI\" web"
