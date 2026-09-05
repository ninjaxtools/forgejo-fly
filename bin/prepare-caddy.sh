#!/bin/sh
set -eu

auth_file=/etc/caddy/auth.caddy
username="${CADDY_BASIC_AUTH_USERNAME:-}"
password="${CADDY_BASIC_AUTH_PASSWORD:-}"

if [ -z "$username" ] && [ -z "$password" ]; then
    : > "$auth_file"
    exit 0
fi

if [ -z "$username" ] || [ -z "$password" ]; then
    printf 'CADDY_BASIC_AUTH_USERNAME and CADDY_BASIC_AUTH_PASSWORD must both be set.\n' >&2
    exit 1
fi

case "$username" in
    *[!A-Za-z0-9._@-]*)
        printf 'CADDY_BASIC_AUTH_USERNAME contains unsupported characters.\n' >&2
        exit 1
        ;;
esac

password_hash="$(/usr/local/bin/caddy hash-password --plaintext "$password")"
cat > "$auth_file" <<EOF
@protected {
    not path /healthz
    not path_regexp public ^(/[^/]+/[^/]+\.git/.*|/api/packages(/.*)?)$
}

basic_auth @protected {
    $username $password_hash
}
EOF
