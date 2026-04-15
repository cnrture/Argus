#!/usr/bin/env bash
#
# Prepend a new <item> entry to appcast.xml for Sparkle auto-updates.
# Idempotent — if an entry for the same version already exists it is
# replaced rather than duplicated.
#
# Usage:
#   ./scripts/update-appcast.sh \
#     --version 1.0.0 \
#     --short-version 1.0.0 \
#     --zip path/to/Argus.zip \
#     --ed-signature BASE64... \
#     --length 12345678 \
#     --release-notes "markdown body"
#

set -euo pipefail

VERSION=""
SHORT_VERSION=""
ZIP_PATH=""
ED_SIGNATURE=""
LENGTH=""
RELEASE_NOTES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --short-version) SHORT_VERSION="$2"; shift 2 ;;
        --zip) ZIP_PATH="$2"; shift 2 ;;
        --ed-signature) ED_SIGNATURE="$2"; shift 2 ;;
        --length) LENGTH="$2"; shift 2 ;;
        --release-notes) RELEASE_NOTES="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

[[ -n "${VERSION}" ]] || { echo "missing --version" >&2; exit 1; }
[[ -n "${SHORT_VERSION}" ]] || { echo "missing --short-version" >&2; exit 1; }
[[ -n "${ZIP_PATH}" ]] || { echo "missing --zip" >&2; exit 1; }
[[ -n "${ED_SIGNATURE}" ]] || { echo "missing --ed-signature" >&2; exit 1; }
[[ -n "${LENGTH}" ]] || { echo "missing --length" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPCAST="${REPO_ROOT}/appcast.xml"
RELEASE_URL="https://github.com/cnrture/Argus/releases/download/v${VERSION}/$(basename "${ZIP_PATH}")"
PUB_DATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
MIN_OS="15.0"

if [[ ! -f "${APPCAST}" ]]; then
    cat > "${APPCAST}" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Argus</title>
        <link>https://argus.candroid.dev/appcast.xml</link>
        <description>Argus release feed</description>
        <language>en</language>
    </channel>
</rss>
EOF
fi

ESCAPED_NOTES=$(python3 - <<PY
import html, sys
print(html.escape("""${RELEASE_NOTES}"""))
PY
)

NEW_ITEM=$(cat <<EOF
        <item>
            <title>Version ${SHORT_VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${SHORT_VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
            <description><![CDATA[${RELEASE_NOTES}]]></description>
            <enclosure
                url="${RELEASE_URL}"
                sparkle:edSignature="${ED_SIGNATURE}"
                length="${LENGTH}"
                type="application/octet-stream" />
        </item>
EOF
)

python3 - "${APPCAST}" "${VERSION}" "${NEW_ITEM}" <<'PY'
import re, sys
path, version, new_item = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as f:
    xml = f.read()

pattern = re.compile(
    r"\s*<item>\s*.*?<sparkle:version>" + re.escape(version) + r"</sparkle:version>.*?</item>",
    re.DOTALL,
)
xml = pattern.sub("", xml)

if "</channel>" not in xml:
    sys.exit("appcast.xml missing </channel>")

xml = xml.replace("</channel>", new_item + "\n    </channel>", 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(xml)
PY

echo "==> appcast.xml updated with v${VERSION}"
