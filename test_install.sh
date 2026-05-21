#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/glassy-system-monitor-test"

rm -rf "$TEMP_DIR"
cp -r "$HERE/package" "$TEMP_DIR"

sed -i 's/"Id": "org.muddyblack.glassySystemMonitor"/"Id": "org.muddyblack.glassySystemMonitorTest"/g' "$TEMP_DIR/metadata.json"
sed -i 's/"Name": "Glassy System Monitor"/"Name": "Glassy System Monitor (Test)"/g' "$TEMP_DIR/metadata.json"

echo "Installing test version of the widget..."
if kpackagetool6 -t Plasma/Applet -l | grep -q "org.muddyblack.glassySystemMonitorTest"; then
    kpackagetool6 -t Plasma/Applet -u "$TEMP_DIR"
else
    kpackagetool6 -t Plasma/Applet -i "$TEMP_DIR"
fi

echo ""
echo "=== Test Widget Installed! ==="
echo "Add 'Glassy System Monitor (Test)' to your desktop or panel."
echo "To uninstall the test version later, run:"
echo "  kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitorTest"
