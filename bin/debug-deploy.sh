#!/bin/sh
set -eu

usage() {
    printf 'Usage: %s <start|stop>\n' "$0" >&2
    exit 1
}

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
repo_root="$(dirname "$script_dir")"
config_path="$repo_root/fly.toml"

[ $# -eq 1 ] || usage

case "$1" in
    start)
        printf 'Enabling DEBUGDEPLOY using %s\n' "$config_path"
        exec fly secrets set -c "$config_path" DEBUGDEPLOY=1
        ;;
    stop)
        printf 'Disabling DEBUGDEPLOY using %s\n' "$config_path"
        exec fly secrets unset -c "$config_path" DEBUGDEPLOY
        ;;
    *)
        usage
        ;;
esac
