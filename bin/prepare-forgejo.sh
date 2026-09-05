#!/bin/sh
set -eu

: "${GITEA_WORK_DIR:=/data/forgejo}"
: "${GITEA_CUSTOM:=$GITEA_WORK_DIR/custom}"
: "${GITEA_TEMP:=/tmp/gitea}"
: "${GITEA_APP_INI:=$GITEA_CUSTOM/conf/app.ini}"
: "${FORGEJO_HOME:=/data/forgejo/git}"

sed_escape() {
    printf '%s' "$1" | sed 's/[\\/&]/\\&/g'
}

set_top_level_key() {
    key="$1"
    value="$2"
    escaped_value="$(sed_escape "$value")"

    if grep -q "^$key[[:space:]]*=" "$GITEA_APP_INI"; then
        sed -i "s/^$key[[:space:]]*=.*/$key = $escaped_value/" "$GITEA_APP_INI"
        return
    fi

    tmp_file="$(mktemp)"
    {
        printf '%s = %s\n' "$key" "$value"
        cat "$GITEA_APP_INI"
    } > "$tmp_file"
    mv "$tmp_file" "$GITEA_APP_INI"
}

mkdir -p \
    "$FORGEJO_HOME" \
    "$GITEA_CUSTOM" \
    "$GITEA_TEMP" \
    "$GITEA_WORK_DIR/data" \
    "$GITEA_WORK_DIR/git/repositories" \
    "$GITEA_WORK_DIR/git/lfs" \
    "$(dirname "$GITEA_APP_INI")"

chown -R forgejo:forgejo "$GITEA_WORK_DIR" "$GITEA_TEMP"
chmod 700 "$FORGEJO_HOME" "$GITEA_CUSTOM" "$GITEA_TEMP" "$(dirname "$GITEA_APP_INI")"

APP_NAME="${APP_NAME:-Forgejo: Beyond coding. We forge.}"
RUN_MODE="${RUN_MODE:-prod}"
RUN_USER="${RUN_USER:-forgejo}"

if [ ! -f "$GITEA_APP_INI" ]; then
    SSH_DOMAIN="${SSH_DOMAIN:-localhost}"
    HTTP_PORT="${HTTP_PORT:-3000}"
    ROOT_URL="${ROOT_URL:-${GITEA__server__ROOT_URL:-}}"
    DISABLE_SSH="${DISABLE_SSH:-false}"
    SSH_PORT="${SSH_PORT:-2222}"
    SSH_LISTEN_PORT="${SSH_LISTEN_PORT:-$SSH_PORT}"
    LFS_START_SERVER="${LFS_START_SERVER:-true}"
    DB_TYPE="${DB_TYPE:-sqlite3}"
    DB_HOST="${DB_HOST:-localhost:3306}"
    DB_NAME="${DB_NAME:-gitea}"
    DB_USER="${DB_USER:-root}"
    DB_PASSWD="${DB_PASSWD:-}"
    INSTALL_LOCK="${INSTALL_LOCK:-false}"
    DISABLE_REGISTRATION="${DISABLE_REGISTRATION:-false}"
    REQUIRE_SIGNIN_VIEW="${REQUIRE_SIGNIN_VIEW:-false}"
    SECRET_KEY="${SECRET_KEY:-}"
    export APP_NAME RUN_MODE RUN_USER SSH_DOMAIN HTTP_PORT ROOT_URL DISABLE_SSH SSH_PORT SSH_LISTEN_PORT LFS_START_SERVER DB_TYPE DB_HOST DB_NAME DB_USER DB_PASSWD INSTALL_LOCK DISABLE_REGISTRATION REQUIRE_SIGNIN_VIEW SECRET_KEY
    envsubst < /etc/templates/forgejo-app.ini.tmpl > "$GITEA_APP_INI"
fi

set_top_level_key APP_NAME "$APP_NAME"
set_top_level_key RUN_USER "$RUN_USER"
set_top_level_key RUN_MODE "$RUN_MODE"
crudini --set "$GITEA_APP_INI" server BUILTIN_SSH_SERVER_USER "$RUN_USER"

printenv | while IFS='=' read -r name value; do
    case "$name" in
        GITEA__*__*)
            rest="${name#GITEA__}"
            section="${rest%%__*}"
            key="${rest#*__}"
            if [ "$section" = default ]; then
                set_top_level_key "$key" "$value"
            else
                crudini --set "$GITEA_APP_INI" "$section" "$key" "$value"
            fi
            ;;
    esac
done

chown forgejo:forgejo "$GITEA_APP_INI"
