#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUTPUT_DIR="$PROJECT_DIR/dist"
STAGING_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT INT TERM

ONBOARD_DIR="$STAGING_DIR/mnt/onboard"
NM_DIR="$ONBOARD_DIR/.adds/nm"
NICKEL_HS_DIR="$ONBOARD_DIR/.adds/nickel-hs"
BACKUP_DIR="$NICKEL_HS_DIR/backup"

if [ ! -f "$PROJECT_DIR/vendor/lib/libsqlite3.so.0" ]; then
    echo "找不到 SQLite runtime library：$PROJECT_DIR/vendor/lib/libsqlite3.so.0" >&2
    exit 1
fi

mkdir -p "$NM_DIR" "$BACKUP_DIR" "$NICKEL_HS_DIR/lib" "$OUTPUT_DIR"

cp -p "$PROJECT_DIR/src/hsBackup" "$NM_DIR/"

# Mutable user data and logs are intentionally not packaged.
cp -p "$PROJECT_DIR/assets/HsKobo.sqlite.template" "$NICKEL_HS_DIR/"
cp -p "$PROJECT_DIR/vendor/sqlite3" "$NICKEL_HS_DIR/"
cp -p "$PROJECT_DIR/vendor/lib/libsqlite3.so.0" "$NICKEL_HS_DIR/lib/"
cp -p "$PROJECT_DIR/src/env.sh" "$BACKUP_DIR/"
cp -p "$PROJECT_DIR/src/sync.sh" "$BACKUP_DIR/"
cp -p "$PROJECT_DIR/src/syncBooks.sh" "$BACKUP_DIR/"
cp -p "$PROJECT_DIR/src/syncAnalytics.sh" "$BACKUP_DIR/"
cp -p "$PROJECT_DIR/src/syncBookmarks.sh" "$BACKUP_DIR/"
cp -p "$PROJECT_DIR/src/runBackup.sh" "$BACKUP_DIR/"

chmod +x "$NM_DIR/hsBackup"
chmod +x "$NICKEL_HS_DIR/sqlite3"
chmod 755 "$NICKEL_HS_DIR/lib/libsqlite3.so.0"
chmod +x "$BACKUP_DIR/sync.sh"
chmod +x "$BACKUP_DIR/syncBooks.sh"
chmod +x "$BACKUP_DIR/syncAnalytics.sh"
chmod +x "$BACKUP_DIR/syncBookmarks.sh"
chmod +x "$BACKUP_DIR/runBackup.sh"

find "$STAGING_DIR" -name ".DS_Store" -delete

OUTPUT_FILE="$OUTPUT_DIR/KoboRoot.tgz"
rm -f "$OUTPUT_FILE"
tar -C "$STAGING_DIR" -czf "$OUTPUT_FILE" mnt

echo "打包完成：$OUTPUT_FILE"
