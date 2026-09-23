#!/usr/bin/env bash
# Compare the GPU shader and canvas renderers (see tools/benchmark.qml).
# Usage: tools/benchmark.sh [seconds per run, default 20]
# Keep the window visible while it runs: a covered window is not drawn.
set -eu
cd "$(dirname "$0")/.."
secs=${1:-20}
for args in "gpu" "canvas" "gpu --static" "canvas --static"; do
  set -- $args
  extra=()
  [[ ${2-} == --static ]] && extra=(--static)
  QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh tools/benchmark.qml -- --renderer "$1" --seconds "$secs" "${extra[@]}" 2>&1 | sed -n 's/^.*RESULT //p'
done
