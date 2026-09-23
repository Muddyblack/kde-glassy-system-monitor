#!/usr/bin/env bash
# `make lint`: qmllint every QML file of the widget, as CI does
# (.github/workflows/lint.yml). Unresolved types are only reported, so
# the Plasma imports the dev shell lacks do not fail it; syntax errors do.
set -euo pipefail
cd "$(dirname "$0")/.."
find package/contents -name '*.qml' -print0 \
    | xargs -0 env QT_TOOL=qmllint tools/qml.sh --unresolved-type info
