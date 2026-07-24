#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"

CURRENT_TIMESTAMP=$(date +"%s")
TEMP_OUTPUT="/tmp/hs-kobo-books-$$.txt"

cleanup() {
    rm -f "$TEMP_OUTPUT"
}
trap cleanup EXIT INT TERM

ensureDatabase

"$SQLITE" <<EOF > "$TEMP_OUTPUT"
.headers off
ATTACH DATABASE '$MY_DB' AS my;
ATTACH DATABASE '$KOBO_DB' AS kobo;

SELECT
    COALESCE((
        SELECT Timestamp
        FROM my.TimeInfo
        WHERE Type = 'contentMaxTime'
    ), 0),
    (
        SELECT MAX(___SyncTime)
        FROM kobo.content
        WHERE ContentType = 6
          AND ContentID NOT LIKE 'file://%'
          AND IsDownloaded = 'true'
    );
EOF

IFS='|' read -r saved_content latest_content < "$TEMP_OUTPUT"

if [ -z "${latest_content:-}" ] || [ "$latest_content" = "$saved_content" ]; then
    showStatus "No new Books."
    echo "Books already up to date."
    exit 0
fi

showStatus "Refreshing Books..."
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
      t1.___SyncTime > COALESCE((
          SELECT Timestamp
          FROM target.TimeInfo
          WHERE Type = 'contentMaxTime'
      ), 0)
      OR EXISTS (
          SELECT 1
          FROM target.Books AS t2
          WHERE t2.ContentID = t1.ContentID
            AND (
                t2.___FileSize != t1.___FileSize
                OR t2.___PercentRead != t1.___PercentRead
                OR t2.TimeSpentReading != t1.TimeSpentReading
                OR t2.ReadStatus != t1.ReadStatus
                OR t2.Timestamp != t1.___SyncTime
                OR t2.DateModified != t1.DateModified
            )
      )
  );

DETACH DATABASE src;
DETACH DATABASE target;

INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES('$CURRENT_TIMESTAMP', 'contentTime');
INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES((SELECT MAX(Timestamp) FROM Books), 'contentMaxTime');
EOF

echo "Books updated."
