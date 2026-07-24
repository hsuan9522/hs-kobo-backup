#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"

CURRENT_TIMESTAMP=$(date +"%s")
TEMP_OUTPUT="/tmp/hs-kobo-analytics-$$.txt"

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
        WHERE Type = 'analyticsMaxTime'
    ), 0),
    (
        SELECT MAX(Timestamp)
        FROM kobo.AnalyticsEvents
        WHERE Type = 'LeaveContent'
    );
EOF

IFS='|' read -r saved_analytics latest_analytics < "$TEMP_OUTPUT"

if [ -z "${latest_analytics:-}" ] || [ "$latest_analytics" = "$saved_analytics" ]; then
    showStatus "No new Analytics events."
    echo "Analytics already up to date."
    exit 0
fi

showStatus "Refreshing Analytics..."
"$SQLITE" "$MY_DB" <<EOF
PRAGMA journal_mode = WAL;
INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES('$CURRENT_TIMESTAMP', 'analyzeTime');

ATTACH DATABASE '$KOBO_DB' AS src;
ATTACH DATABASE '$MY_DB' AS target;

INSERT OR IGNORE INTO target.Analytics
SELECT
    t1.Id,
    t1.Timestamp,
    t1.Attributes,
    t1.Metrics,
    strftime('%Y-%m-%d', datetime(t1.Timestamp, '+08:00')) AS Date,
    COALESCE(json_extract(t1.Attributes, '$.title'), t2.Title) AS Title,
    COALESCE(json_extract(t1.Attributes, '$.author'), t2.Author) AS Author,
    json_extract(t1.Metrics, '$.SecondsRead') AS ReadingTime
FROM src.AnalyticsEvents AS t1
LEFT JOIN Books AS t2
    ON t2.ContentId = json_extract(t1.Attributes, '$.volumeid')
WHERE t1.Type = 'LeaveContent'
  AND t1.Timestamp > COALESCE((
      SELECT Timestamp
      FROM target.TimeInfo
      WHERE Type = 'analyticsMaxTime'
  ), 0);

DETACH DATABASE src;
DETACH DATABASE target;

INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES((SELECT MAX(Timestamp) FROM Analytics), 'analyticsMaxTime');
EOF

echo "Analytics updated."
