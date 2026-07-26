#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"

ensureDatabase
showStatus "Refreshing Bookmarks..."

has_data=$($SQLITE "$MY_DB" "SELECT 1 FROM Bookmark LIMIT 1;")

if [ -z "$has_data" ]; then
    # B 資料庫的 Bookmark 表沒有資料，將從 A 資料庫複製所有記錄...

    $SQLITE "$KOBO_DB" <<EOF >/tmp/bookmark_with_title.sql
.mode insert Bookmark
SELECT b.*, c.Title as title, c.Attribution as author
FROM Bookmark b
LEFT JOIN content c ON b.VolumeID = c.ContentID;
EOF

    # 將數據導入 B
    $SQLITE "$MY_DB" ".read /tmp/bookmark_with_title.sql"
    rm /tmp/bookmark_with_title.sql
    showStatus "Bookmarks sync complete"

else
    # B 資料庫的 Bookmark 表有資料，正在比對差異...

    $SQLITE "$MY_DB" <<EOF
ATTACH DATABASE '$KOBO_DB' AS db_a;

-- 確保添加了BEGIN和COMMIT事務語句
BEGIN;

-- 先刪除已有的表以避免衝突
DROP TABLE IF EXISTS missing_records;

-- 建立持久表存儲差異記錄
CREATE TABLE missing_records AS
SELECT b.*, c.Title as title, c.Attribution as author
FROM db_a.Bookmark b
LEFT JOIN db_a.content c ON b.VolumeID = c.ContentID
WHERE NOT EXISTS (
    SELECT 1 FROM Bookmark 
    WHERE Bookmark.BookmarkID = b.BookmarkID 
);

COMMIT;
EOF

    diff_count=$($SQLITE "$MY_DB" "SELECT COUNT(*) FROM missing_records;")

    if [ "$diff_count" -gt 0 ]; then
        echo "發現 $diff_count 條記錄在 A 中存在但不在 B 中，正在複製..."

        # 將差異記錄插入到 B 資料庫
        $SQLITE "$MY_DB" "INSERT INTO Bookmark SELECT * FROM missing_records"
        showStatus "Bookmarks sync complete."

    else
        echo "沒有發現需要同步的記錄。"
        showStatus "No need to sync bookmarks."
    fi
fi
