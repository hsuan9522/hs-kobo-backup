#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

case "${1:-all}" in
    analytics)
        "$SCRIPT_DIR/syncBooks.sh"
        "$SCRIPT_DIR/syncAnalytics.sh"
        ;;
    bookmarks)
        "$SCRIPT_DIR/syncBookmarks.sh"
        ;;
    all)
        "$SCRIPT_DIR/syncBooks.sh"
        "$SCRIPT_DIR/syncAnalytics.sh"
        "$SCRIPT_DIR/syncBookmarks.sh"
        ;;
    *)
        echo "Usage: $0 {analytics|bookmarks|all}" >&2
        exit 2
        ;;
esac
