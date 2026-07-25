# hs-kobo-backup

在 Kobo 閱讀器上備份書籍資料、閱讀分析事件、劃線與筆記，並集中儲存在
`HsKobo.sqlite`。

產生的資料庫可以上傳至 [kobo.cjhsuan.com](https://kobo.cjhsuan.com/)
查看與使用，也可以提供給
[kobo-reading-calendar](https://github.com/hsuan9522/kobo-reading-calendar)
產生閱讀日曆。

## 功能

- 備份 Kobo 書庫中的書籍資訊與閱讀進度。
- 備份 `AnalyticsEvents` 中的閱讀事件。
- 備份劃線、書籤與筆記。
- 只同步尚未保存或已有變化的資料。
- 將資料集中保存在獨立的 `HsKobo.sqlite`，不修改
  `.kobo/KoboReader.sqlite`。
- 支援 NickelMenu。
- 如果裝置已安裝 FBInk，執行時會在畫面上顯示進度；沒有 FBInk 也能正常備份。
- 可以獨立使用，也可以作為 `kobo-reading-calendar` 的建置依賴。

## 重要提醒

Kobo 的 `AnalyticsEvents` 可能在重新啟動、連接 Wi-Fi 或連接 USB 後被清除。
若希望盡可能保存完整的閱讀紀錄，建議在進行上述操作前先執行一次備份。

Bookmarks 採追加備份：

- Kobo 資料庫中新增的劃線與筆記會被複製到 `HsKobo.sqlite`。
- 已經備份的資料不會因為 Kobo 上的原始紀錄被刪除而自動刪除。
- 如需刪除已備份的紀錄，必須直接編輯 `HsKobo.sqlite`。

本工具不是完整的 Kobo 檔案系統備份，也不會備份 EPUB、PDF 或其他書籍檔案本身。

## 資料庫內容

`HsKobo.sqlite` 主要包含：

| Table | 用途 |
| --- | --- |
| `Books` | 書籍資訊、閱讀進度與狀態 |
| `Analytics` | 閱讀事件與閱讀時間 |
| `Bookmark` | 書籤、劃線與筆記 |
| `TimeInfo` | 上次執行與同步進度 |


## 安裝

需要先安裝
[NickelMenu](https://pgaskin.net/NickelMenu/#install)。

從 [GitHub Releases](https://github.com/hsuan9522/hs-kobo-backup/releases)
下載最新的 `KoboRoot.tgz`，將檔案放入 Kobo 的 `.kobo/` 目錄，安全退出裝置
後，Kobo 會自動安裝並重新啟動。

安裝包可以獨立使用，不需要安裝 Reading Calendar。若使用
`kobo-reading-calendar` 的整合安裝包，它也會將本 repository 的固定版本放入
同一個 `KoboRoot.tgz`，不需要重複安裝。



## 使用方式

安裝後，NickelMenu 會出現「備份 Kobo 資料」。此行為會備份：
1. 書籍資訊與閱讀進度。
2. 劃線與筆記。
3. 內建分析資料。

備份完成後，資料庫位於：

```text
/mnt/onboard/.adds/nickel-hs/HsKobo.sqlite
```

將 Kobo 連接至電腦後，可以把這個檔案上傳至
[kobo.cjhsuan.com](https://kobo.cjhsuan.com/)。


## 指令

`sync.sh` 支援三種模式：

```sh
# 同步 Books 與 Analytics
/mnt/onboard/.adds/nickel-hs/backup/sync.sh analytics

# 同步 Bookmarks
/mnt/onboard/.adds/nickel-hs/backup/sync.sh bookmarks

# 同步全部資料
/mnt/onboard/.adds/nickel-hs/backup/sync.sh all
```

## Log

每次從 NickelMenu 執行完整備份時，會覆寫：

```text
/mnt/onboard/.adds/nickel-hs/logs/hs-kobo-backup.log
```

如果備份由 `kobo-reading-calendar` 呼叫，相關輸出會寫入 Calendar 自己的：

```text
/mnt/onboard/.adds/nickel-hs/logs/reading-calendar.log
```

## 解除安裝

先將 Kobo 連接至電腦。如果需要保留備份資料，請先複製：

```text
.adds/nickel-hs/HsKobo.sqlite
```

然後刪除整個 `.adds/nickel-hs/` 。

若裝置仍要使用 Reading Calendar，就都不能刪除。

完成後安全退出 Kobo 並重新啟動，讓 NickelMenu 重新載入設定。

## 與 Reading Calendar 搭配

Reading Calendar 只使用：

```sh
sync.sh analytics
```

資料同步完成後，再由 Calendar 自己的統計腳本讀取 `HsKobo.sqlite`、輸出月份
JSON 並產生日曆圖片。Books 與 Analytics 的拷貝 SQL 只由
`hs-kobo-backup` 維護。

## Repository 結構

```text
hs-kobo-backup/
├── src/
│   ├── env.sh
│   ├── sync.sh
│   ├── syncBooks.sh
│   ├── syncAnalytics.sh
│   ├── syncBookmarks.sh
│   ├── runBackup.sh
│   └── hsBackup
├── assets/
│   └── HsKobo.sqlite.template
├── vendor/
│   ├── sqlite3
│   └── lib/
│       └── libsqlite3.so.0
├── build.sh
└── .github/workflows/release.yml
```

- `src/`：安裝到 Kobo 後執行的 scripts 與 NickelMenu 設定。`sync.sh`
  負責 dispatch，Books、Analytics 和 Bookmarks 的同步邏輯分別位於各自檔案。
- `assets/`：首次執行時使用的空白資料庫模板。
- `vendor/`：Kobo ARM 平台使用的 SQLite executable 與 shared library。
- `build.sh`：組合上述檔案並產生安裝包。

