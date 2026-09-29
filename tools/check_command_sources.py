#!/usr/bin/env python3
"""Fail on a raw executable DataSource: it remembers every command string forever.

Run each command through PlasmaCommandSource instead (one disposable source per
command). Only that file may name the executable engine.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WRAPPER = "PlasmaCommandSource.qml"
RAW = re.compile(r'engine:\s*"executable"')

offenders = [
    path.relative_to(REPO)
    for folder in ("package", "hyprland")
    for path in (REPO / folder).rglob("*.qml")
    if path.name != WRAPPER and RAW.search(path.read_text())
]
if offenders:
    sys.exit(
        "Raw executable DataSource (leaks one entry per command); use "
        f"{WRAPPER}:\n  " + "\n  ".join(map(str, offenders))
    )
print("command sources: PASS")
