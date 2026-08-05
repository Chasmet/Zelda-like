#!/usr/bin/env python3
"""Validate the exported Android APK and write its entry list."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: verify_apk.py <apk> <entries-output>", file=sys.stderr)
        return 2

    apk_path = Path(sys.argv[1])
    entries_path = Path(sys.argv[2])

    if not apk_path.is_file() or apk_path.stat().st_size <= 0:
        raise SystemExit(f"APK absent ou vide: {apk_path}")

    with zipfile.ZipFile(apk_path, "r") as archive:
        bad_entry = archive.testzip()
        if bad_entry is not None:
            raise SystemExit(f"Entrée APK corrompue: {bad_entry}")
        names = archive.namelist()

    if "classes.dex" not in names:
        raise SystemExit("classes.dex absent de l'APK")
    if not any(name.startswith("lib/arm64-v8a/") and name.endswith(".so") for name in names):
        raise SystemExit("Bibliothèque native ARM64 absente de l'APK")
    if not any(name.startswith("assets/") for name in names):
        raise SystemExit("Ressources Godot absentes de l'APK")

    entries_path.parent.mkdir(parents=True, exist_ok=True)
    entries_path.write_text("\n".join(names) + "\n", encoding="utf-8")
    print(f"APK ZIP OK: {len(names)} entrées, {apk_path.stat().st_size} octets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
