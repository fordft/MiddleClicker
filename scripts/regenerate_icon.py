#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
iconset = root / ".build/AppIcon.iconset"
iconset.parent.mkdir(exist_ok=True)
subprocess.run(["xcrun", "swift", str(root / "Assets/Icon.swift"), str(iconset)], check=True)
subprocess.run(["xcrun", "iconutil", "-c", "icns", str(iconset), "-o", str(root / "Assets/AppIcon.icns")], check=True)
shutil.copy2(iconset / "icon_256x256.png", root / "Assets/Icon.png")
print("Generated AppIcon.icns and Icon.png from the editable vector drawing.")
