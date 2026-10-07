#!/usr/bin/env python3
"""Build a universal macOS 13+ application using the installed Xcode SDK."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build"
DIST = ROOT / "dist"
APP = DIST / "MiddleClicker.app"


def run(*command):
    subprocess.run(command, check=True)


def build_architecture(architecture):
    output = BUILD / ("MiddleClicker-" + architecture)
    sources = sorted((ROOT / "Sources/MiddleClicker").glob("*.swift"))
    run("xcrun", "swiftc", "-swift-version", "5", "-O", "-module-name", "MiddleClicker",
        "-target", architecture + "-apple-macos13.0", "-sdk", SDK,
        "-framework", "AppKit", "-framework", "ApplicationServices", "-framework", "CoreGraphics",
        "-framework", "IOKit", "-framework", "ServiceManagement",
        *map(str, sources), "-o", str(output))
    return output


if __name__ == "__main__":
    BUILD.mkdir(exist_ok=True)
    DIST.mkdir(exist_ok=True)
    SDK = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
    with ThreadPoolExecutor(max_workers=2) as pool:
        binaries = list(pool.map(build_architecture, ["arm64", "x86_64"]))
    if APP.exists():
        shutil.rmtree(APP)
    executable_folder = APP / "Contents/MacOS"
    resources = APP / "Contents/Resources"
    executable_folder.mkdir(parents=True)
    resources.mkdir(parents=True)
    binary = executable_folder / "MiddleClicker"
    run("xcrun", "lipo", "-create", *map(str, binaries), "-output", str(binary))
    binary.chmod(0o755)
    shutil.copy2(ROOT / "packaging/Info.plist", APP / "Contents/Info.plist")
    shutil.copy2(ROOT / "Assets/AppIcon.icns", resources / "AppIcon.icns")
    shutil.copy2(ROOT / "LICENSE", resources / "LICENSE")
    shutil.copy2(ROOT / "packaging/Read Me.txt", resources / "Read Me.txt")
    (APP / "Contents/PkgInfo").write_bytes(b"APPL????")
    identity = os.environ.get("MIDDLECLICKER_SIGNING_IDENTITY", "-")
    timestamp = "--timestamp=none" if identity == "-" else "--timestamp"
    run("/usr/bin/codesign", "--force", "--sign", identity, "--options", "runtime", timestamp, str(APP))
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(APP))
    architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(binary)], text=True).split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise RuntimeError("The release must include both arm64 and x86_64.")
    with (APP / "Contents/Info.plist").open("rb") as file:
        version = plistlib.load(file)["CFBundleShortVersionString"]
    print("Built MiddleClicker " + version + " for Apple Silicon and Intel: " + str(APP))
