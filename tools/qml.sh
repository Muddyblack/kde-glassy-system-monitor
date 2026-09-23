#!/usr/bin/env bash
# Run a QML file (or, with QT_TOOL=qmltestrunner, the tests) with the Qt that
# owns the tool, ignoring the desktop session's
# QML and plugin paths: on NixOS those point at the session's Qt build, and
# mixing two Qt builds in one process fails to load or crashes. Plugins built
# for the same Qt version (qtsvg from the dev shell, say) are kept.
set -eu
qml_bin="$(command -v "${QT_TOOL:-qml}")"
qt_prefix="$(dirname "$(dirname "$(readlink -f "$qml_bin")")")"
qt_version="${qt_prefix##*-}"
plugins=""
IFS=: read -r -a entries <<< "${QT_PLUGIN_PATH:-}:${QT_ADDITIONAL_PACKAGES_PREFIX_PATH:-}"
for entry in "${entries[@]}"; do
  dir="${entry%/lib/qt-6/plugins}/lib/qt-6/plugins"
  dir="${dir/-dev\/lib/\/lib}"
  case "${entry%%/lib/*}" in
    *-"$qt_version" | *-"$qt_version"-dev) [ -d "$dir" ] && plugins="$plugins:$dir" ;;
  esac
done
for pkg in /nix/store/*-qtsvg-"$qt_version"; do
  [ -d "$pkg/lib/qt-6/plugins" ] && plugins="$plugins:$pkg/lib/qt-6/plugins" && break
done
exec env -u QML2_IMPORT_PATH -u NIXPKGS_QT6_QML_IMPORT_PATH \
  QT_PLUGIN_PATH="${plugins#:}" \
  QML_IMPORT_PATH="$qt_prefix/lib/qt-6/qml${NIXPKGS_QML_SEARCH_PATHS:+:$NIXPKGS_QML_SEARCH_PATHS}" \
  QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORMTHEME=generic \
  "$qml_bin" "$@"
