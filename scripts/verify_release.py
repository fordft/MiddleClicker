#!/usr/bin/env python3
"""Verify that both downloadable archives contain the app that was built."""
import hashlib
from pathlib import Path
import plistlib
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
dist = root / "dist"
app = dist / "MiddleClicker.app"
with (app / "Contents/Info.plist").open("rb") as file:
    version = plistlib.load(file)["CFBundleShortVersionString"]
prefix = "MiddleClicker-" + version + "-universal"
verification = root / ".build/release-verification"
if verification.exists():
    shutil.rmtree(verification)
verification.mkdir(parents=True)
mount = verification / "mounted"
mount.mkdir()
extraction = verification / "zip"
extraction.mkdir()


def run(*args):
    subprocess.run(args, check=True)


def manifest(folder):
    return {str(path.relative_to(folder)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in folder.rglob("*") if path.is_file()}


expected = manifest(app)
for filename in [prefix + ".dmg", prefix + ".zip"]:
    digest = hashlib.sha256((dist / filename).read_bytes()).hexdigest()
    if digest + "  " + filename not in (dist / "SHA256SUMS.txt").read_text():
        raise RuntimeError("Incorrect checksum for " + filename)
run("/usr/bin/ditto", "-x", "-k", str(dist / (prefix + ".zip")), str(extraction))
zip_app = extraction / "MiddleClicker.app"
if manifest(zip_app) != expected:
    raise RuntimeError("ZIP app differs from the built app.")
run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(zip_app))
run("/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount),
    str(dist / (prefix + ".dmg")))
try:
    dmg_app = mount / "MiddleClicker.app"
    if manifest(dmg_app) != expected:
        raise RuntimeError("DMG app differs from the built app.")
    if not (mount / "Applications").is_symlink() or (mount / "Applications").readlink() != Path("/Applications"):
        raise RuntimeError("Applications drag-and-drop target is missing.")
    if not (mount / ".DS_Store").is_file() or not (mount / ".background/background.png").is_file():
        raise RuntimeError("DMG installer layout is missing.")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(dmg_app))
    architectures = subprocess.check_output(["xcrun", "lipo", "-archs",
        str(dmg_app / "Contents/MacOS/MiddleClicker")], text=True).split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise RuntimeError("Download is not a universal app.")
finally:
    run("/usr/bin/hdiutil", "detach", str(mount))
print("PASS: DMG and ZIP contain the identical signed universal app, drag-and-drop layout, and matching checksums.")
