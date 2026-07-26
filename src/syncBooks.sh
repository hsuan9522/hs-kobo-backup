#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"

CURRENT_TIMESTAMP=$(date +"%s")

ensureDatabase

showStatus "Checking Books..."
sqlite_output=$(
    "$SQLITE" "$MY_DB" <<EOF
PRAGMA journal_mode = WAL;
ATTACH DATABASE '$KOBO_DB' AS src;
ATTACH DATABASE '$MY_DB' AS target;

INSERT OR REPLACE INTO target.Books
SELECT *, Attribution AS Author, ___SyncTime AS Timestamp
FROM src.content AS t1
WHERE ContentType = 6
  AND (
      (Accessibility = -1 AND IsDownloaded = 'true')
      OR Accessibility IN (1, 2)
  )
  AND (
      NOT EXISTS (
          SELECT 1
          FROM target.Books AS t2
          WHERE t2.ContentID = t1.ContentID
      )
      OR EXISTS (
          SELECT 1
          FROM target.Books AS t2
          WHERE t2.ContentID = t1.ContentID
            AND (
                t2.___PercentRead IS NOT t1.___PercentRead
                OR t2.TimeSpentReading IS NOT t1.TimeSpentReading
                OR t2.ReadStatus IS NOT t1.ReadStatus
                OR t2.Timestamp IS NOT t1.___SyncTime
                OR t2.DateModified IS NOT t1.DateModified
            )
      )
  );

SELECT 'BOOK_CHANGES|' || changes();

DETACH DATABASE src;
DETACH DATABASE target;

INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES('$CURRENT_TIMESTAMP', 'contentTime');
INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES((SELECT MAX(Timestamp) FROM Books), 'contentMaxTime');
EOF
)

changed_count=$(printf '%s\n' "$sqlite_output" |
    awk -F'|' '$1 == "BOOK_CHANGES" { print $2 }')

if [ "${changed_count:-0}" -gt 0 ]; then
    showStatus "Books sync complete."
    echo "Books updated: $changed_count row(s)."
else
    showStatus "No Books changes."
    echo "Books already up to date."
fi
