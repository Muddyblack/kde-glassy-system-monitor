#!/usr/bin/env bash
# Run the Quickshell desktop widget; extra arguments go to `qs` (e.g. ipc).
set -eu
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../shell.qml"
export QT_QPA_PLATFORMTHEME=generic
export QT_QUICK_CONTROLS_STYLE=Basic
if (($#)); then
  exec qs -p "$CONFIG" "$@"
fi
exec qs -n -p "$CONFIG"
