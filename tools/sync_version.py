#!/usr/bin/env python3
"""Generate studio/ProjectVersion.js from package/metadata.json (the one source of truth).

    tools/sync_version.py          write the file
    tools/sync_version.py --check  exit 1 if it is out of date
"""
import json, pathlib, sys

root = pathlib.Path(__file__).resolve().parent.parent
version = json.loads((root / "package/metadata.json").read_text())["KPlugin"]["Version"]
target = root / "package/contents/ui/studio/ProjectVersion.js"
text = f'// Generated from package/metadata.json by tools/sync_version.py. Do not edit.\nvar current = "{version}";\n'

if "--check" in sys.argv:
    if not target.exists() or target.read_text() != text:
        sys.exit(f"{target.relative_to(root)} is out of date: run tools/sync_version.py")
else:
    target.write_text(text)
