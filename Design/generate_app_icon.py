#!/usr/bin/env python3
"""Petpal heart+paw icon — exact square PNGs for every App Icon slot (fixes macOS scrunch)."""
from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("Install Pillow: pip3 install Pillow")


def cubic_bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return (
        u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
        u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
    )


# Scale artwork up so heart+paw fill more of the icon (reads better at small sizes).
DESIGN_CENTER = (512.0, 512.0)  # geometric center of canvas
ART_SCALE = 1.37  # “hair” bigger; lower if corners clip
# Heart shape reads top-heavy when centered on math midpoint — nudge whole mark down.
OFFSET_Y = 28.0  # design-space px at 1024; increase if still high, decrease if bottom clips


def scale_art(x: float, y: float) -> tuple[float, float]:
    cx, cy = DESIGN_CENTER
    sx = cx + (x - cx) * ART_SCALE
    sy = cy + (y - cy) * ART_SCALE + OFFSET_Y
    return sx, sy


def heart_points_1024(n: int = 100) -> list[tuple[float, float]]:
    segs = [
        ((512, 298), (420, 220), (268, 248), (268, 410)),
        ((268, 410), (268, 520), (400, 640), (512, 730)),
        ((512, 730), (624, 640), (756, 520), (756, 410)),
        ((756, 410), (756, 248), (604, 220), (512, 298)),
    ]
    pts = []
    per = max(1, n // 4)
    for p0, p1, p2, p3 in segs:
        for i in range(per):
            t = i / per
            x, y = cubic_bezier(p0, p1, p2, p3, t)
            pts.append((x, y))
    return pts


def render_icon(size: int) -> Image.Image:
    s = size / 1024.0
    im = Image.new("RGB", (size, size), "#4A90D9")
    dr = ImageDraw.Draw(im)

    # Paw (scaled in design space, then to pixels)
    orange = "#F4845F"
    cx0, cy0 = 512.0, 498.0
    mcx, mcy = scale_art(cx0, cy0 + 52.0)
    mrx, mry = 72 * ART_SCALE, 88 * ART_SCALE
    dr.ellipse(
        [
            int((mcx - mrx) * s),
            int((mcy - mry) * s),
            int((mcx + mrx) * s),
            int((mcy + mry) * s),
        ],
        fill=orange,
    )
    for dx, dy, r in [
        (-78, -28, 38),
        (78, -28, 38),
        (-42, -72, 34),
        (42, -72, 34),
    ]:
        tx, ty = scale_art(cx0 + dx, cy0 + dy)
        rad = int(r * ART_SCALE * s)
        x, y = int(tx * s), int(ty * s)
        dr.ellipse([x - rad, y - rad, x + rad, y + rad], fill=orange)

    # White heart outline on top
    hp = [(scale_art(x, y)[0] * s, scale_art(x, y)[1] * s) for x, y in heart_points_1024(140)]
    stroke = max(5, int(52 * s))
    closed = hp + [hp[0]]
    dr.line(closed, fill="#FFFFFF", width=stroke, joint="curve")

    return im


def write_png_pil(path: Path, im: Image.Image):
    im.save(path, "PNG", optimize=True)


def main():
    root = Path(__file__).resolve().parent.parent
    out_dir = root / "Assets.xcassets" / "AppIcon.appiconset"
    out_dir.mkdir(parents=True, exist_ok=True)

    sizes = [
        ("AppIcon-mac-16.png", 16),
        ("AppIcon-mac-32.png", 32),
        ("AppIcon-mac-64.png", 64),
        ("AppIcon-mac-128.png", 128),
        ("AppIcon-mac-256.png", 256),
        ("AppIcon-mac-512.png", 512),
        ("AppIcon-ios-1024.png", 1024),
    ]
    for name, sz in sizes:
        im = render_icon(sz)
        write_png_pil(out_dir / name, im)
        assert im.size == (sz, sz), (name, im.size)
        print(f"OK {name} {sz}x{sz}")

    contents = {
        "images": [
            {"filename": "AppIcon-ios-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "filename": "AppIcon-ios-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "tinted"}],
                "filename": "AppIcon-ios-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {"filename": "AppIcon-mac-16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
            {"filename": "AppIcon-mac-32.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
            {"filename": "AppIcon-mac-32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
            {"filename": "AppIcon-mac-64.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
            {"filename": "AppIcon-mac-128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
            {"filename": "AppIcon-mac-256.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
            {"filename": "AppIcon-mac-256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
            {"filename": "AppIcon-mac-512.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
            {"filename": "AppIcon-mac-512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
            {"filename": "AppIcon-ios-1024.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (out_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print("Updated Assets.xcassets/AppIcon.appiconset — clean build (Shift+Cmd+K) then run again.")


if __name__ == "__main__":
    main()
