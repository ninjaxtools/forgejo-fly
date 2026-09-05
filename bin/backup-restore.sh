#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  backup-restore.sh [snapshot]

Environment:
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  RESTIC_REPOSITORY
  RESTIC_PASSWORD
EOF
  exit 1
}

if [ $# -gt 1 ]; then
  usage
fi

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID must be set}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY must be set}"
: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY must be set}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD must be set}"

snapshot="${1:-latest}"
restore_path='/data/forgejo'

clear_directory() {
  local dir=$1

  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

staging_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT INT TERM

echo "Restoring snapshot '$snapshot' from $RESTIC_REPOSITORY into $restore_path ..."
restic restore "$snapshot" --target "$staging_dir" --include "$restore_path"

restored_path="$staging_dir$restore_path"
if [ ! -e "$restored_path" ]; then
  echo "Snapshot '$snapshot' did not contain $restore_path" >&2
  exit 1
fi

clear_directory "$restore_path"
cp -a "$restored_path"/. "$restore_path"/
echo "Restore completed at $restore_path."
