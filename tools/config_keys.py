#!/usr/bin/env python3
"""Regenerate the cfg_* property list in configStudio.qml from main.xml.

Plasma only hands a settings page the keys it declares as cfg_ properties, so
the list must match main.xml exactly. `make config` rewrites it in place.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
xml = (root / "package/contents/config/main.xml").read_text()
page = root / "package/contents/ui/configStudio.qml"
qml = page.read_text()

types = {"String": "string", "Bool": "bool", "Int": "int", "Double": "real", "StringList": "var"}
lines = []
for name, kind in re.findall(r'<entry\s+name="([^"]+)"\s+type="([^"]+)"', xml):
    for suffix in ("", "Default"):
        lines.append(f"    property {types.get(kind, 'var')} cfg_{name}{suffix}")

block = re.compile(r"(?:    property \w+ cfg_\w+\n)+")
match = block.search(qml)
if not match:
    sys.exit("configStudio.qml: no cfg_ block found")
updated = qml[: match.start()] + "\n".join(lines) + "\n" + qml[match.end():]
if "--check" in sys.argv:
    sys.exit(0 if updated == qml else "configStudio.qml is out of date: run make config")
page.write_text(updated)
