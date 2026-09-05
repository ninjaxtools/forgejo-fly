#!/bin/bash
set -uo pipefail

required_vars=(
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  RESTIC_REPOSITORY
  RESTIC_PASSWORD
)

missing_vars=()
for var_name in "${required_vars[@]}"; do
  if [ -z "${!var_name:-}" ]; then
    missing_vars+=("$var_name")
  fi
done

if [ "${#missing_vars[@]}" -gt 0 ]; then
  echo "Restic backups disabled; missing ${missing_vars[*]}." >&2
  exec sleep infinity
fi

BACKUP_INTERVAL_SECONDS="${RESTIC_BACKUP_INTERVAL_SECONDS:-3600}"
BACKUP_PATHS=("/data")

KEEP_HOURLY=24
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

run_backup() {
  echo "Starting restic backup..."
  restic backup "${BACKUP_PATHS[@]}" || return $?

  echo "Pruning old backups..."
  restic forget \
    --keep-hourly "$KEEP_HOURLY" \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --prune || return $?

  echo "Checking repository..."
  restic check || return $?
  echo "Backup completed successfully."
}

while true; do
  if run_backup; then
    :
  else
    status=$?
    echo "Restic backup failed with status $status." >&2
  fi

  sleep "$BACKUP_INTERVAL_SECONDS"
done
