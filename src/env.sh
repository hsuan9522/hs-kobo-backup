FOLDER="/mnt/onboard/.adds/nickel-hs"
KOBO_DB="/mnt/onboard/.kobo/KoboReader.sqlite"
MY_DB="${FOLDER}/HsKobo.sqlite"
SQLITE="${FOLDER}/sqlite3"

export LD_LIBRARY_PATH="${FOLDER}/lib:${LD_LIBRARY_PATH:-}"

showStatus() {
    if command -v fbink >/dev/null 2>&1; then
        fbink -qpm -y -2 "$1"
    fi
}

ensureDatabase() {
    if [ ! -f "$MY_DB" ]; then
        cp "$FOLDER/HsKobo.sqlite.template" "$MY_DB"
    fi
}
