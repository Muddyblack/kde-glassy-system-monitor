#!/usr/bin/env bash
# Render the website screenshots at 2x (see tools/gallery.qml).
set -eu
cd "$(dirname "$0")/.."
out=docs/readme
mkdir -p "$out"
QT_SCALE_FACTOR=${SCALE:-2} QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh tools/gallery.qml -- --out "$PWD/$out" 2>&1 | grep -E 'gallery:|Error|error' || true
# The network window on demo data (tools/network.qml).
for shot in "overview:" "apps:app:org.mozilla.firefox" "history:" "containers:"; do
  tab=${shot%%:*} expand=${shot#*:}
  QT_SCALE_FACTOR=${SCALE:-2} tools/qml.sh tools/network.qml -- --save "$PWD/$out/network-$tab.png" --tab "$tab" ${expand:+--expand "$expand"} 2>&1 | grep -E 'network:|Error|error' || true
done
ls "$out"
