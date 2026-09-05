#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
template="$repo_root/fly.toml.tmpl"
config="$repo_root/fly.toml"
cd "$repo_root"

for command_name in fly openssl sed tr; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 1
    fi
done

prompt() {
    local variable_name=$1
    local message=$2
    local default_value=${3:-}
    local value

    if [ -n "$default_value" ]; then
        read -r -p "$message [$default_value]: " value
        value=${value:-$default_value}
    else
        while [ -z "${value:-}" ]; do
            read -r -p "$message: " value
        done
    fi
    printf -v "$variable_name" '%s' "$value"
}

prompt app_name 'Fly app name'
case "$app_name" in
    -*|*-|*[!a-z0-9-]*)
        printf 'App names may only contain lowercase letters, numbers, and internal hyphens.\n' >&2
        exit 1
        ;;
esac

printf 'Available Fly regions: https://fly.io/docs/reference/regions/\n'
prompt primary_region 'Fly primary region' 'nrt'
case "$primary_region" in
    *[!a-z0-9]*)
        printf 'Invalid Fly region: %s\n' "$primary_region" >&2
        exit 1
        ;;
esac

prompt admin_username 'Forgejo admin username'
if [ "${admin_username,,}" = admin ]; then
    printf 'The username "admin" is reserved by Forgejo. Choose another username.\n' >&2
    exit 1
fi
case "$admin_username" in
    -*|*-|*[!A-Za-z0-9._-]*)
        printf 'The Forgejo username may only contain letters, numbers, ., _, and internal hyphens.\n' >&2
        exit 1
        ;;
esac
prompt admin_email 'Forgejo admin email' "admin@$app_name.fly.dev"
if [[ "$admin_email" != *@* ]]; then
    printf 'Invalid email address: %s\n' "$admin_email" >&2
    exit 1
fi

require_signin_view=true
read -r -p 'Force visitors to sign in before viewing Forgejo? [Y/n]: ' force_forgejo_login
case "$force_forgejo_login" in
    ''|y|Y|yes|YES)
        ;;
    n|N|no|NO)
        require_signin_view=false
        ;;
    *)
        printf 'Please answer yes or no.\n' >&2
        exit 1
        ;;
esac

caddy_username=
caddy_password=
read -r -p 'Enable Caddy HTTP basic auth? [y/N]: ' enable_caddy_auth
case "$enable_caddy_auth" in
    y|Y|yes|YES)
        prompt caddy_username 'Caddy basic auth username' "$admin_username"
        case "$caddy_username" in
            *[!A-Za-z0-9._@-]*)
                printf 'The Caddy username may only contain letters, numbers, ., _, @, and -.\n' >&2
                exit 1
                ;;
        esac

        while [ -z "$caddy_password" ]; do
            read -r -s -p 'Caddy basic auth password: ' caddy_password
            printf '\n'
        done
        read -r -s -p 'Confirm Caddy basic auth password: ' caddy_password_confirmation
        printf '\n'
        if [ "$caddy_password" != "$caddy_password_confirmation" ]; then
            printf 'Caddy passwords do not match.\n' >&2
            exit 1
        fi
        ;;
    ''|n|N|no|NO)
        ;;
    *)
        printf 'Please answer yes or no.\n' >&2
        exit 1
        ;;
esac

admin_password="$(openssl rand -base64 24 | tr -d '\n')"

sed \
    -e "s/__APP_NAME__/$app_name/g" \
    -e "s/__PRIMARY_REGION__/$primary_region/g" \
    -e "s/__REQUIRE_SIGNIN_VIEW__/$require_signin_view/g" \
    "$template" > "$config"

printf '\nGenerated Forgejo admin credentials:\n'
printf '  Username: %s\n' "$admin_username"
printf '  Password: %s\n' "$admin_password"

printf '\nCreating Fly app %s...\n' "$app_name"
fly apps create "$app_name"

secrets=(
    "FORGEJO_ADMIN_USERNAME=$admin_username"
    "FORGEJO_ADMIN_EMAIL=$admin_email"
    "FORGEJO_ADMIN_PASSWORD=$admin_password"
)
if [ -n "$caddy_username" ]; then
    secrets+=(
        "CADDY_BASIC_AUTH_USERNAME=$caddy_username"
        "CADDY_BASIC_AUTH_PASSWORD=$caddy_password"
    )
fi
fly secrets set --stage --app "$app_name" "${secrets[@]}"

printf '\nDeploying Forgejo...\n'
fly deploy --config "$config"

printf '\nForgejo is available at https://%s.fly.dev/\n' "$app_name"
printf 'Admin username: %s\n' "$admin_username"
printf 'Admin password: %s\n' "$admin_password"
if [ -n "$caddy_username" ]; then
    printf 'Caddy basic auth username: %s\n' "$caddy_username"
fi
