#!/usr/bin/env python3
"""Package drag-and-drop DMG, app ZIP, and SHA-256 checksums."""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

from ds_store import DSStore
from mac_alias import Alias

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build"
DIST = ROOT / "dist"
APP = DIST / "MiddleClicker.app"


def run(*args):
    subprocess.run(args, check=True)


def make_zip(app, destination):
    if destination.exists():
        destination.unlink()
    run("/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(destination))


if __name__ == "__main__":
    if not APP.is_dir():
        raise RuntimeError("Run scripts/build.py first.")
    with (APP / "Contents/Info.plist").open("rb") as file:
        version = plistlib.load(file)["CFBundleShortVersionString"]
    prefix = "MiddleClicker-" + version + "-universal"
    identity = os.environ.get("MIDDLECLICKER_SIGNING_IDENTITY", "-")
    profile = os.environ.get("MIDDLECLICKER_NOTARY_PROFILE")
    if profile:
        if identity == "-":
            raise RuntimeError("Notarization requires a Developer ID Application signing identity.")
        notarization_zip = BUILD / "notarization.zip"
        make_zip(APP, notarization_zip)
        run("xcrun", "notarytool", "submit", str(notarization_zip), "--keychain-profile", profile, "--wait")
        run("xcrun", "stapler", "staple", str(APP))

    staging = BUILD / "dmg-staging"
    mountpoint = BUILD / "dmg-mount"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    (staging / ".background").mkdir()
    shutil.copytree(APP, staging / "MiddleClicker.app")
    (staging / "Applications").symlink_to("/Applications", target_is_directory=True)
    shutil.copy2(ROOT / "packaging/Read Me.txt", staging / "Read Me.txt")
    shutil.copy2(ROOT / "Assets/AppIcon.icns", staging / ".VolumeIcon.icns")
    run("xcrun", "swift", str(ROOT / "Assets/DiskImageBackground.swift"),
        str(staging / ".background/background.png"))
    mountpoint.mkdir(exist_ok=True)
    temporary_image = BUILD / "MiddleClicker-rw.dmg"
    run("/usr/bin/hdiutil", "create", "-ov", "-size", "32m", "-fs", "HFS+", "-format", "UDRW",
        "-volname", "MiddleClicker", "-srcfolder", str(staging), str(temporary_image))
    run("/usr/bin/hdiutil", "attach", "-nobrowse", "-mountpoint", str(mountpoint), str(temporary_image))
    try:
        background = Alias.for_file(str(mountpoint / ".background/background.png")).to_bytes()
        with DSStore.open(str(mountpoint / ".DS_Store"), "w+") as store:
            store["."]["bwsp"] = {"WindowBounds": "{{260, 160}, {800, 480}}",
                "ShowToolbar": False, "ShowStatusBar": False, "ShowPathbar": False,
                "ShowSidebar": False, "ShowTabView": False, "ContainerShowSidebar": False,
                "SidebarWidth": 0}
            store["."]["icvp"] = {"viewOptionsVersion": 1, "backgroundType": 2,
                "backgroundImageAlias": background, "iconSize": 96.0, "textSize": 13.0,
                "gridSpacing": 100.0, "gridOffsetX": 0.0, "gridOffsetY": 0.0,
                "labelOnBottom": True, "showIconPreview": True, "showItemInfo": False,
                "arrangeBy": "none", "backgroundColorRed": 1.0,
                "backgroundColorGreen": 1.0, "backgroundColorBlue": 1.0}
            store["."]["vstl"] = ("type", b"icnv")
            store["."]["vSrn"] = ("long", 1)
            store["MiddleClicker.app"]["Iloc"] = (220, 220)
            store["Applications"]["Iloc"] = (580, 220)
            store["Read Me.txt"]["Iloc"] = (400, 390)
        run("xcrun", "SetFile", "-a", "C", str(mountpoint))
    finally:
        run("/usr/bin/hdiutil", "detach", str(mountpoint))

    dmg = DIST / (prefix + ".dmg")
    zip_file = DIST / (prefix + ".zip")
    run("/usr/bin/hdiutil", "convert", str(temporary_image), "-format", "UDZO", "-imagekey",
        "zlib-level=9", "-ov", "-o", str(dmg))
    if identity != "-":
        run("/usr/bin/codesign", "--force", "--sign", identity, "--timestamp", str(dmg))
    if profile:
        run("xcrun", "notarytool", "submit", str(dmg), "--keychain-profile", profile, "--wait")
        run("xcrun", "stapler", "staple", str(dmg))
    make_zip(APP, zip_file)
    checksums = DIST / "SHA256SUMS.txt"
    checksums.write_text("".join(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name + "\n"
        for path in [dmg, zip_file]))
    run("/usr/bin/hdiutil", "verify", str(dmg))
    print("Release assets: " + str(dmg) + ", " + str(zip_file) + ", " + str(checksums))
