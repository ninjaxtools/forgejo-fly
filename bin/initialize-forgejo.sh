#!/bin/sh
set -eu

: "${FORGEJO_ADMIN_USERNAME:?FORGEJO_ADMIN_USERNAME must be set}"
: "${FORGEJO_ADMIN_EMAIL:?FORGEJO_ADMIN_EMAIL must be set}"
: "${FORGEJO_ADMIN_PASSWORD:?FORGEJO_ADMIN_PASSWORD must be set}"

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

run_forgejo() {
    command="exec /usr/local/bin/forgejo"
    for argument in "$@"; do
        command="$command $(shell_quote "$argument")"
    done
    su forgejo -s /bin/sh -c "$command"
}

if ! run_forgejo -c "$GITEA_APP_INI" migrate >/tmp/forgejo-migrate.log 2>&1; then
    cat /tmp/forgejo-migrate.log >&2
    exit 1
fi

if run_forgejo -c "$GITEA_APP_INI" admin user create \
    --username "$FORGEJO_ADMIN_USERNAME" \
    --password "$FORGEJO_ADMIN_PASSWORD" \
    --email "$FORGEJO_ADMIN_EMAIL" \
    --admin \
    --must-change-password=false >/tmp/forgejo-admin-create.log 2>&1; then
    printf 'Created Forgejo admin user %s.\n' "$FORGEJO_ADMIN_USERNAME"
    exit 0
fi

run_forgejo -c "$GITEA_APP_INI" admin user list >/tmp/forgejo-admin-list.log 2>/dev/null || true
while read -r _id username _rest; do
    if [ "$username" = "$FORGEJO_ADMIN_USERNAME" ]; then
        printf 'Forgejo admin user %s already exists; leaving it unchanged.\n' "$FORGEJO_ADMIN_USERNAME"
        exit 0
    fi
done < /tmp/forgejo-admin-list.log

cat /tmp/forgejo-admin-create.log >&2
exit 1
