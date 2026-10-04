#!/usr/bin/env bash
# Pack src/ into dist/AkatiOS_v<version>.apbx (zip, password "malte") and write dist/SHA256SUMS.txt.
# Usage: ./build.sh            -> version read from src/playbook.conf <Version>
#        ./build.sh 1.2.0      -> override version
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
DIST="$ROOT/dist"
PASSWORD="malte"
CONF="$SRC/playbook.conf"

[[ -f "$CONF" ]] || { echo "error: $CONF not found" >&2; exit 1; }

# 1. playbook.conf must be valid XML
if command -v xmllint >/dev/null; then
    xmllint --noout "$CONF" || { echo "error: playbook.conf is not valid XML" >&2; exit 1; }
elif command -v python3 >/dev/null; then
    python3 -c 'import sys,xml.dom.minidom as m; m.parse(sys.argv[1])' "$CONF" \
        || { echo "error: playbook.conf is not valid XML" >&2; exit 1; }
else
    echo "warning: no xmllint/python3, skipping XML check" >&2
fi

# 2. Version
VERSION="${1:-$(tr -d '\r' < "$CONF" | sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' | head -n1)}"
[[ -n "$VERSION" ]] || { echo "error: could not read <Version> from playbook.conf" >&2; exit 1; }

# 3. Warn about text files that lost CRLF line endings
bad=0
while IFS= read -r -d '' f; do
    # UTF-16 files (BOM FF FE, e.g. some .reg) are skipped: byte check does not apply
    [[ "$(head -c2 "$f" | od -An -tx1 | tr -d ' ')" == "fffe" ]] && continue
    if perl -0777 -ne 'exit(/(?<!\r)\n/ ? 0 : 1)' "$f"; then
        echo "warning: LF line endings in ${f#$ROOT/}" >&2; bad=1
    fi
done < <(find "$SRC" -type f \( -iname '*.yml' -o -iname '*.conf' -o -iname '*.ps1' -o -iname '*.psm1' \
    -o -iname '*.psd1' -o -iname '*.cmd' -o -iname '*.bat' -o -iname '*.reg' -o -iname '*.md' -o -iname '*.txt' \) -print0)
[[ $bad -eq 0 ]] || echo "warning: some files are not CRLF (see above)" >&2

# 4. Pack (contents of src/ at the archive root)
mkdir -p "$DIST"
OUT="AkatiOS_v${VERSION}.apbx"
rm -f "$DIST/$OUT"
if command -v 7z >/dev/null; then
    (cd "$SRC" && 7z a -tzip -mx1 -p"$PASSWORD" -y "$DIST/$OUT" . >/dev/null)
elif command -v zip >/dev/null; then
    (cd "$SRC" && zip -q -r -X -P "$PASSWORD" "$DIST/$OUT" .)
else
    echo "error: need 7z or zip" >&2; exit 1
fi

# 5. Checksums (sha256sum format, covers every .apbx in dist/)
(cd "$DIST" && sha256sum -- *.apbx > SHA256SUMS.txt)

echo "built: dist/$OUT"
cat "$DIST/SHA256SUMS.txt"
