#!/usr/bin/env python3
"""Reconstruit le GLB optimisé et animé de Yvane avant l'import Godot."""

from __future__ import annotations

import base64
import hashlib
import lzma
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTS = [
    "asset_payloads/yvane/000.b85",
    "asset_payloads/yvane/001.b85",
    "asset_payloads/yvane/002.b85",
    "asset_payloads/yvane/003.b85",
    "asset_payloads/yvane/004.b85",
    "asset_payloads/yvane/005.b85",
    "asset_payloads/yvane/006_007.b85",
    "asset_payloads/yvane/008_009.b85",
    "asset_payloads/yvane/010_011.b85",
    "asset_payloads/yvane/012a.b85",
    "asset_payloads/yvane/012b.b85",
    "asset_payloads/yvane/012c.b85",
    "asset_payloads/yvane/012d.b85",
    "asset_payloads/yvane/012e.b85",
    "asset_payloads/yvane/014.b85",
]
EXPECTED_SIZE = 220_844
EXPECTED_SHA256 = "045bc844558b23a976351194ab1e3e819023080d9ceaca7000f5cb1e9e56ac91"
OUTPUT = ROOT / "uploaded_models/joueur_2_yvane.glb"


def main() -> None:
    encoded = "".join((ROOT / path).read_text(encoding="ascii").strip() for path in PARTS)
    raw = lzma.decompress(base64.b85decode(encoded.encode("ascii")))
    digest = hashlib.sha256(raw).hexdigest()

    if len(raw) != EXPECTED_SIZE:
        raise RuntimeError(f"Taille Yvane incorrecte: {len(raw)} au lieu de {EXPECTED_SIZE}")
    if digest != EXPECTED_SHA256:
        raise RuntimeError(f"SHA-256 Yvane incorrect: {digest}")
    if raw[:4] != b"glTF":
        raise RuntimeError("Le modèle Yvane reconstruit n'est pas un GLB valide")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(raw)
    print(f"Yvane GLB reconstruit: {OUTPUT.relative_to(ROOT)} — {len(raw)} octets — {digest}")


if __name__ == "__main__":
    main()
