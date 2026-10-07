# Changelog

## 2.0.0 — 2026-10-07

- Rebuilt the mouse remapping engine to preserve relative deltas, modifiers, pressure, click count, timestamp, and event targeting metadata.
- Track physical Fn key state independently of software modifier flags.
- Keep middle-button drags active until the click is released, even after Fn is released.
- Release owned middle-button gestures on pause, normal quit, sleep, and tap interruption, and recover disabled event taps.
- Add pause controls, permission status, settings shortcuts, and an interactive middle-click test window.
- Enable native Launch at Login on first launch from Applications.
- Add a new app icon and designed drag-and-drop DMG.
- Ship universal Apple Silicon and Intel builds for macOS 13 or later, app ZIP, and checksums.
- Rewrite the README and add regression tests and automated release-package verification.

The release requires Accessibility and Input Monitoring. It is ad hoc signed and not Developer ID notarized.

## 1.0 — 2025-11-24

Original Fn + click/drag utility and disk-image download.
