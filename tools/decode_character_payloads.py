#!/usr/bin/env python3
"""Reconstruit et vérifie les modèles GLB stockés sous forme Base85 + XZ."""

from __future__ import annotations

import base64
import hashlib
import json
import lzma
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD_DIR = ROOT / "asset_payloads"
MANIFEST_PATH = PAYLOAD_DIR / "manifest.json"


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    for name, entry in manifest.items():
        encoded = "".join(
            (PAYLOAD_DIR / part).read_text(encoding="ascii").strip()
            for part in entry["parts"]
        )
        compressed = base64.b85decode(encoded.encode("ascii"))
        raw = lzma.decompress(compressed)

        expected_size = int(entry["raw_size"])
        expected_sha = str(entry["sha256"])
        actual_sha = hashlib.sha256(raw).hexdigest()

        if len(raw) != expected_size:
            raise RuntimeError(
                f"{name}: taille incorrecte {len(raw)} au lieu de {expected_size}"
            )
        if actual_sha != expected_sha:
            raise RuntimeError(
                f"{name}: SHA-256 incorrect {actual_sha} au lieu de {expected_sha}"
            )
        if raw[:4] != b"glTF":
            raise RuntimeError(f"{name}: le fichier reconstruit n'est pas un GLB valide")

        output = ROOT / entry["output"]
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(raw)
        print(f"{name}: {output.relative_to(ROOT)} — {len(raw)} octets — {actual_sha}")


if __name__ == "__main__":
    main()
