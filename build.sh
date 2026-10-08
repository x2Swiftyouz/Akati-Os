#!/usr/bin/env bash
# Pack each playbook into dist/ (zip, password "malte") and write dist/SHA256SUMS.txt:
#   src/        -> dist/AkatiOS-Win11_v<version>.apbx  (Windows 11)
#   src-win10/  -> dist/AkatiOS-Win10_v<version>.apbx  (Windows 10)
# The version is read from each playbook.conf <Version>.
# Usage: ./build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
PASSWORD="malte"
VARIANTS=("src:AkatiOS-Win11" "src-win10:AkatiOS-Win10")

mkdir -p "$DIST"
rm -f "$DIST"/*.apbx "$DIST/SHA256SUMS.txt"

build_one() {
    local SRC="$ROOT/$1" PREFIX="$2"
    local CONF="$SRC/playbook.conf"

    [[ -f "$CONF" ]] || { echo "error: $CONF not found" >&2; exit 1; }

    # 1. playbook.conf must be valid XML with pages AME Wizard accepts
    if command -v python3 >/dev/null; then
        python3 "$ROOT/tools/check-playbook.py" "$CONF" || exit 1
    elif command -v xmllint >/dev/null; then
        echo "warning: no python3, only checking that playbook.conf is valid XML" >&2
        xmllint --noout "$CONF" || { echo "error: playbook.conf is not valid XML" >&2; exit 1; }
    else
        echo "warning: no python3/xmllint, skipping playbook.conf check" >&2
    fi

    # 2. Version
    local VERSION
    VERSION="$(tr -d '\r' < "$CONF" | sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' | head -n1)"
    [[ -n "$VERSION" ]] || { echo "error: could not read <Version> from $CONF" >&2; exit 1; }

    # 3. Warn about text files that lost CRLF line endings
    local bad=0 f
    while IFS= read -r -d '' f; do
        # UTF-16 files (BOM FF FE, e.g. some .reg) are skipped: byte check does not apply
        [[ "$(head -c2 "$f" | od -An -tx1 | tr -d ' ')" == "fffe" ]] && continue
        if perl -0777 -ne 'exit(/(?<!\r)\n/ ? 0 : 1)' "$f"; then
            echo "warning: LF line endings in ${f#$ROOT/}" >&2; bad=1
        fi
    done < <(find "$SRC" -type f \( -iname '*.yml' -o -iname '*.conf' -o -iname '*.ps1' -o -iname '*.psm1' \
        -o -iname '*.psd1' -o -iname '*.cmd' -o -iname '*.bat' -o -iname '*.reg' -o -iname '*.md' -o -iname '*.txt' \) -print0)
    [[ $bad -eq 0 ]] || echo "warning: some files are not CRLF (see above)" >&2

    # 4. Pack (contents of the source folder at the archive root)
    local OUT="${PREFIX}_v${VERSION}.apbx"
    if command -v 7z >/dev/null; then
        (cd "$SRC" && 7z a -tzip -mx1 -p"$PASSWORD" -y "$DIST/$OUT" . >/dev/null)
    elif command -v zip >/dev/null; then
        (cd "$SRC" && zip -q -r -X -P "$PASSWORD" "$DIST/$OUT" .)
    else
        echo "error: need 7z or zip" >&2; exit 1
    fi

    # 5. Checksum (sha256sum format)
    (cd "$DIST" && sha256sum -- "$OUT" >> SHA256SUMS.txt)
    echo "built: dist/$OUT"
}

for v in "${VARIANTS[@]}"; do
    build_one "${v%%:*}" "${v#*:}"
done

cat "$DIST/SHA256SUMS.txt"
