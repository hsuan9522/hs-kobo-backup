#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"

CURRENT_TIMESTAMP=$(date +"%s")

ensureDatabase

analytics_primary_key=$("$SQLITE" "$MY_DB" \
    "SELECT group_concat(name, '|') FROM (
        SELECT name
        FROM pragma_table_info('Analytics')
        WHERE pk > 0
        ORDER BY pk
    );")

case "$analytics_primary_key" in
"Id")
    # 舊資料庫：執行 migration
    showStatus "Updating Analytics database..."
    "$SQLITE" "$MY_DB" <<EOF
.bail on
PRAGMA journal_mode = WAL;
BEGIN IMMEDIATE;

ALTER TABLE Analytics RENAME TO Analytics_before_migration;
CREATE TABLE Analytics (
    Id TEXT,
    Timestamp TEXT,
    Attributes TEXT,
    Metrics TEXT,
    Date TEXT,
    Title TEXT,
    Author TEXT,
    ReadingTime INTEGER,
    PRIMARY KEY (Id, Timestamp)
);

INSERT INTO Analytics (
    Id,
    Timestamp,
    Attributes,
    Metrics,
    Date,
    Title,
    Author,
    ReadingTime
)
SELECT
    Id,
    Timestamp,
    Attributes,
    Metrics,
    Date,
    Title,
    Author,
    ReadingTime
FROM Analytics_before_migration;

CREATE TEMP TABLE analytics_migration_check (
    is_valid INTEGER CHECK (is_valid = 1)
);
INSERT INTO analytics_migration_check
SELECT (
    (SELECT COUNT(*) FROM Analytics)
    =
    (SELECT COUNT(*) FROM Analytics_before_migration)
);
DROP TABLE analytics_migration_check;

DROP TABLE Analytics_before_migration;
COMMIT;
EOF
    echo "Analytics database migration complete."
    ;;
"Id|Timestamp")
    # 新資料庫：什麼都不做
    ;;
*)
    echo "Unsupported Analytics primary key: ${analytics_primary_key:-none}" >&2
    exit 1
    ;;
esac

showStatus "Checking Analytics..."
sqlite_output=$(
    "$SQLITE" "$MY_DB" <<EOF
.bail on
PRAGMA journal_mode = WAL;
ATTACH DATABASE '$KOBO_DB' AS src;
BEGIN;

INSERT OR IGNORE INTO Analytics
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
LEFT JOIN main.Books AS t2
    ON t2.ContentId = json_extract(t1.Attributes, '$.volumeid')
WHERE t1.Type = 'LeaveContent'
  AND NOT EXISTS (
      SELECT 1
      FROM main.Analytics AS t3
      WHERE t3.Id = t1.Id
        AND t3.Timestamp = t1.Timestamp
  );

SELECT 'ANALYTICS_CHANGES|' || changes();

INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES('$CURRENT_TIMESTAMP', 'analyzeTime');

INSERT OR REPLACE INTO TimeInfo(Timestamp, Type)
VALUES((SELECT MAX(Timestamp) FROM Analytics), 'analyticsMaxTime');
COMMIT;
DETACH DATABASE src;
EOF
)

changed_count=$(printf '%s\n' "$sqlite_output" |
    awk -F'|' '$1 == "ANALYTICS_CHANGES" { print $2 }')

if [ "${changed_count:-0}" -gt 0 ]; then
    showStatus "Analytics sync complete."
    echo "Analytics updated: $changed_count row(s)."
else
    showStatus "No new Analytics events."
    echo "Analytics already up to date."
fi
