#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/glassy-system-monitor-test"

ID="org.muddyblack.glassySystemMonitorTest"

rm -rf "$TEMP_DIR"
cp -r "$HERE/package" "$TEMP_DIR"

# Replace both the Id and Icon properties (which use the widget ID)
sed -i "s/org.muddyblack.glassySystemMonitor/$ID/g" "$TEMP_DIR/metadata.json"
sed -i 's/"Name": "Glassy System Monitor"/"Name": "Glassy System Monitor (Test)"/g' "$TEMP_DIR/metadata.json"

# Install the icon to the user's local hicolor icon theme directory
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"
cp "$HERE/package/icon.png" "$ICON_DIR/$ID.png"

echo "Installing test version of the widget..."
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q -w "$ID"; then
    kpackagetool6 -t Plasma/Applet -u "$TEMP_DIR" 2>/dev/null
    echo "Updated existing test install."
else
    kpackagetool6 -t Plasma/Applet -i "$TEMP_DIR" 2>/dev/null
    echo "Installed fresh test widget."
fi

echo ""
echo "=== Test Widget Installed! ==="
echo "Add 'Glassy System Monitor (Test)' to your desktop or panel."
echo "To uninstall the test version later, run:"
echo "  kpackagetool6 -t Plasma/Applet -r $ID"
echo "  rm -f $HOME/.local/share/icons/hicolor/256x256/apps/$ID.png"
