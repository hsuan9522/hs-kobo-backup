#!/bin/sh
set -eu

NICKEL_HS_DIR="/mnt/onboard/.adds/nickel-hs"
BACKUP_DIR="$NICKEL_HS_DIR/backup"
LOG_DIR="$NICKEL_HS_DIR/logs"
LOG_FILE="$LOG_DIR/hs-kobo-backup.log"

mkdir -p "$LOG_DIR"
exec >"$LOG_FILE" 2>&1
echo "=== HS Kobo Backup started: $(date) ==="

showFailure() {
    status=$?
    if [ "$status" -ne 0 ] && command -v fbink >/dev/null 2>&1; then
        fbink -qpm -y -2 "HS Kobo Backup failed. Check logs."
    fi
}
trap showFailure EXIT

"$BACKUP_DIR/sync.sh" all

echo "=== HS Kobo Backup completed: $(date) ==="
if command -v fbink >/dev/null 2>&1; then
    fbink -qpm -y -2 "HS Kobo Backup completed."
fi
