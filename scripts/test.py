#!/usr/bin/env python3
"""Run gesture and metadata tests without posting mouse events or reading keys."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
build = root / ".build"
build.mkdir(exist_ok=True)
binary = build / "MiddleClickerTests"
subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-O",
    "-framework", "CoreGraphics", str(root / "Sources/MiddleClicker/PhysicalFnState.swift"),
    str(root / "Sources/MiddleClicker/MiddleClickState.swift"),
    str(root / "Sources/MiddleClicker/MouseEventTransformer.swift"), str(root / "Tests/main.swift"),
    "-o", str(binary)], check=True)
subprocess.run([str(binary)], check=True)
