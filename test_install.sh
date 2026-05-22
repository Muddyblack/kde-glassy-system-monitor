#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
METADATA="$HERE/package/metadata.json"

ID="$(grep -oE '"Id":[[:space:]]*"[^"]+"' "$METADATA" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
NAME="$(grep -oE '"Name":[[:space:]]*"[^"]+"' "$METADATA" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
TEST_ID="${ID}Test"
TEMP_DIR="/tmp/$(basename "$HERE")-test"

rm -rf "$TEMP_DIR"
cp -r "$HERE/package" "$TEMP_DIR"

sed -i "s/$ID/$TEST_ID/g" "$TEMP_DIR/metadata.json"
sed -i "s/\"Name\": \"$NAME\"/\"Name\": \"$NAME (Test)\"/g" "$TEMP_DIR/metadata.json"

ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"
cp "$HERE/package/icon.png" "$ICON_DIR/$TEST_ID.png"

echo "Installing test version of the widget..."
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q -w "$TEST_ID"; then
    kpackagetool6 -t Plasma/Applet -u "$TEMP_DIR" 2>/dev/null
    echo "Updated existing test install."
else
    kpackagetool6 -t Plasma/Applet -i "$TEMP_DIR" 2>/dev/null
    echo "Installed fresh test widget."
fi

echo ""
echo "=== Test Widget Installed! ==="
echo "Add '$NAME (Test)' to your desktop or panel."
echo "To uninstall the test version later, run:"
echo "  kpackagetool6 -t Plasma/Applet -r $TEST_ID"
echo "  rm -f $ICON_DIR/$TEST_ID.png"
