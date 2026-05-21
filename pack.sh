#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$HERE/package/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
OUT="$HERE/glassy-system-monitor-${VERSION}.plasmoid"

rm -f "$OUT"
(cd "$HERE/package" && zip -r "$OUT" . -x '*.swp' '*~')
echo "wrote $OUT"
