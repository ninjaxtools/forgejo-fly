#!/bin/bash
set -euo pipefail

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID must be set}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY must be set}"
: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY must be set}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD must be set}"

if restic snapshots >/dev/null 2>&1; then
  echo "Restic repository is already initialized."
  exit 0
fi

echo "Initializing restic repository at $RESTIC_REPOSITORY..."
restic init
echo "Restic repository initialized successfully."
