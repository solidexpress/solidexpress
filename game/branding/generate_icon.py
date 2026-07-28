#!/usr/bin/env python3
"""Generate SolidExpress app icon PNGs from the brand master artwork.

Master: docs/branding/logo-source.png
  Isometric open-shell locomotive (printable CAD teaching model): hollow
  boiler tube + open-top cab so wireframe reveals interiors opaque solids
  would hide; connected buffers/wheels/axles; ghosted teal workplane;
  solid blue faces + white edge strokes (same language as the original L-mark).

Re-run after replacing logo-source.png:
  python3 game/branding/generate_icon.py
"""
from __future__ import annotations

from PIL import Image, ImageDraw
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "docs", "branding", "logo-source.png")
SIZES = {
    "game/icon.png": 128,
    "game/branding/icon-512.png": 512,
    "docs/branding/logo.png": 512,
}

ACCENT_TOP = (155, 205, 255)


def make_icon(source: Image.Image, n: int) -> Image.Image:
    pad = n * 0.08
    corner_r = n * 0.2
    fitted = source.convert("RGBA").resize((n, n), Image.Resampling.LANCZOS)
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([pad, pad, n - pad, n - pad], radius=corner_r, fill=255)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out = Image.composite(fitted, out, mask)
    draw = ImageDraw.Draw(out)
    draw.rounded_rectangle(
        [pad + 1, pad + 1, n - pad - 1, n - pad - 1],
        radius=corner_r,
        outline=(ACCENT_TOP[0], ACCENT_TOP[1], ACCENT_TOP[2], 35),
        width=max(1, n // 256),
    )
    return out


def main() -> None:
    if not os.path.isfile(SOURCE):
        raise SystemExit(f"Missing brand master: {SOURCE}")
    source = Image.open(SOURCE)
    for rel, sz in SIZES.items():
        full = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        make_icon(source, sz).save(full, "PNG", optimize=True)
        print(f"Wrote {full} ({sz}x{sz})")


if __name__ == "__main__":
    main()
