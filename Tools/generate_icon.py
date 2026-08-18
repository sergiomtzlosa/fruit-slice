#!/usr/bin/env python3
"""Generate the Fruit Slice app icon and macOS .icns bundle."""
from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "FruitNinja" / "Resources"
RES.mkdir(parents=True, exist_ok=True)

S = 1024
SS = 2
R = S * SS
rng = None


def rounded_mask(size: int, margin: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((margin, margin, size - margin, size - margin),
                        radius=radius, fill=255)
    return mask


def radial_background(size: int, margin: int, radius: int) -> Image.Image:
    img = Image.new("RGB", (size, size), (5, 11, 20))
    px = img.load()
    c = size * 0.38
    max_d = math.hypot(size * 0.75, size * 0.75)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / max_d
            t = min(1.0, d) ** 1.3
            # deep teal to midnight
            px[x, y] = (
                int(10 + 22 * (1 - t)),
                int(43 + 55 * (1 - t)),
                int(58 + 60 * (1 - t)),
            )
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(12, 0, -1):
        rr = size * 0.68 * i / 12
        a = int(55 * (1 - i / 14) ** 1.5)
        gd.ellipse((c - rr, c - rr, c + rr, c + rr),
                   fill=(60, 255, 200, a))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.04))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    mask = rounded_mask(size, margin, radius)
    img.putalpha(mask)
    return img


def generate_master() -> Image.Image:
    margin = int(S * 0.085)
    radius = int(S * 0.225)
    art = radial_background(R, margin * SS, radius * SS)

    # subtle diagonal accents
    overlay = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(-8, 14):
        x = i * 140 * SS
        od.line((x, 0, x + 600 * SS, R), fill=(173, 255, 231, 11), width=2 * SS)
    # inner edge
    od.rounded_rectangle((margin * SS + 18 * SS, margin * SS + 18 * SS,
                          R - margin * SS - 18 * SS, R - margin * SS - 18 * SS),
                         radius=(radius - 14) * SS, outline=(160, 255, 229, 45),
                         width=2 * SS)
    art = Image.alpha_composite(art, overlay)

    d = ImageDraw.Draw(art, "RGBA")

    # drop shadow under fruit
    shadow = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((R * 0.22, R * 0.7, R * 0.77, R * 0.84), fill=(0, 0, 0, 165))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22 * SS))
    art = Image.alpha_composite(art, shadow)
    d = ImageDraw.Draw(art, "RGBA")

    # watermelon half
    box = (R * 0.16, R * 0.25, R * 0.74, R * 0.79)
    d.pieslice(box, 180, 360, fill=(28, 112, 58, 255))
    d.pieslice((box[0] + 22 * SS, box[1] + 22 * SS, box[2] - 22 * SS, box[3] - 16 * SS),
               180, 360, fill=(119, 218, 112, 255))
    d.pieslice((box[0] + 44 * SS, box[1] + 44 * SS, box[2] - 44 * SS, box[3] - 36 * SS),
               180, 360, fill=(248, 67, 95, 255))
    d.pieslice((box[0] + 80 * SS, box[1] + 70 * SS, box[2] - 100 * SS, box[3] - 90 * SS),
               198, 344, fill=(255, 108, 126, 75))
    # seeds, placed inside the pink flesh above the flat cut
    for i, (sx, sy) in enumerate([(0.30, 0.44), (0.385, 0.35), (0.47, 0.435),
                                  (0.56, 0.345), (0.34, 0.49), (0.61, 0.46),
                                  (0.48, 0.49)]):
        x, y = R * sx, R * sy
        ang = -0.35 + i * 0.28
        w, h = 9 * SS, 17 * SS
        seed = Image.new("RGBA", (int(w * 2.4), int(h * 2.4)), (0, 0, 0, 0))
        sdraw = ImageDraw.Draw(seed)
        sdraw.ellipse((w * 0.7, h * 0.7, w * 1.7, h * 1.7), fill=(25, 24, 30, 245))
        seed = seed.rotate(math.degrees(ang), resample=Image.Resampling.BICUBIC,
                           center=(w * 1.2, h * 1.2))
        art.alpha_composite(seed, (int(x - w * 1.2), int(y - h * 1.2)))
    d = ImageDraw.Draw(art, "RGBA")
    # crisp rind outline along the dome; no floating bar across the icon
    d.arc(box, 180, 360, fill=(8, 51, 28, 235), width=6 * SS)

    # blade crossing diagonally
    blade_glow = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    bg = ImageDraw.Draw(blade_glow)
    p0, p1 = (R * 0.42, R * 0.69), (R * 0.91, R * 0.29)
    bg.line((p0[0], p0[1], p1[0], p1[1]), fill=(71, 255, 227, 130), width=32 * SS)
    bg.line((p0[0], p0[1], p1[0], p1[1]), fill=(255, 255, 255, 95), width=9 * SS)
    blade_glow = blade_glow.filter(ImageFilter.GaussianBlur(16 * SS))
    art = Image.alpha_composite(art, blade_glow)
    d = ImageDraw.Draw(art, "RGBA")

    # blade body
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    w = 21 * SS
    blade_pts = [
        (p0[0] + nx * w, p0[1] + ny * w),
        (p1[0] + nx * w * 0.4, p1[1] + ny * w * 0.4),
        (p1[0] + dx * 0.08 + nx * w * 0.1, p1[1] + dy * 0.08 + ny * w * 0.1),
        (p1[0] - nx * w * 0.4, p1[1] - ny * w * 0.4),
        (p0[0] - nx * w, p0[1] - ny * w),
    ]
    d.polygon(blade_pts, fill=(236, 251, 255, 255))
    d.polygon([(p0[0] + nx * w * 0.5, p0[1] + ny * w * 0.5),
               (p1[0] + nx * w * 0.1, p1[1] + ny * w * 0.1),
               (p1[0] - nx * w * 0.1, p1[1] - ny * w * 0.1),
               (p0[0] - nx * w * 0.4, p0[1] - ny * w * 0.4)],
              fill=(147, 255, 235, 255))
    # handle, overlapping the blade base so there is no gap
    h0 = (p0[0] + dx * 0.018, p0[1] + dy * 0.018)
    h1 = (p0[0] - dx * 0.235, p0[1] - dy * 0.235)
    d.line((h0[0], h0[1], h1[0], h1[1]),
           fill=(28, 35, 47, 255), width=34 * SS)
    # metal guard
    gx, gy = p0[0] - dx * 0.03, p0[1] - dy * 0.03
    guard = 60 * SS
    d.line((gx + nx * guard, gy + ny * guard,
            gx - nx * guard, gy - ny * guard),
           fill=(126, 146, 166, 255), width=10 * SS)
    d.line((gx + nx * guard * 0.9 + dx * 0.012, gy + ny * guard * 0.9 + dy * 0.012,
            gx - nx * guard * 0.9 + dx * 0.012, gy - ny * guard * 0.9 + dy * 0.012),
           fill=(206, 228, 241, 190), width=3 * SS)
    # wrap highlight along the handle
    d.line((h0[0] + nx * 5 * SS, h0[1] + ny * 5 * SS,
            h1[0] + nx * 5 * SS, h1[1] + ny * 5 * SS),
           fill=(91, 112, 131, 255), width=8 * SS)
    # sparkles
    for (sx, sy, sr, a) in [(0.84, 0.24, 28, 220), (0.79, 0.36, 12, 170),
                            (0.3, 0.25, 8, 140), (0.7, 0.8, 6, 100)]:
        cx, cy, rr = R * sx, R * sy, sr * SS
        d.polygon([(cx, cy - rr), (cx + rr * 0.3, cy - rr * 0.3),
                   (cx + rr, cy), (cx + rr * 0.3, cy + rr * 0.3),
                   (cx, cy + rr), (cx - rr * 0.3, cy + rr * 0.3),
                   (cx - rr, cy), (cx - rr * 0.3, cy - rr * 0.3)],
                  fill=(255, 236, 155, a))

    # final rim highlight
    d.rounded_rectangle((margin * SS + 3 * SS, margin * SS + 3 * SS,
                         R - margin * SS - 3 * SS, R - margin * SS - 3 * SS),
                        radius=(radius - 3) * SS, outline=(255, 255, 255, 35),
                        width=3 * SS)

    # Clip every layer (accents, sparks, blade, rim) to the rounded-square mask.
    mask = rounded_mask(R, margin * SS, radius * SS)
    art.putalpha(ImageChops.multiply(art.getchannel("A"), mask))

    return art.resize((S, S), Image.Resampling.LANCZOS)


def build_icns(master: Image.Image) -> None:
    iconset = RES / ".AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)
    specs = [
        (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
    ]
    for size, name in specs:
        master.resize((size, size), Image.Resampling.LANCZOS).save(iconset / name)
    subprocess.run([
        "iconutil", "-c", "icns", str(iconset), "-o", str(RES / "AppIcon.icns")
    ], check=True)
    shutil.rmtree(iconset)
    master.save(RES / "AppIcon-1024.png")
    print(f"Generated {RES / 'AppIcon.icns'}")


def main() -> None:
    master = generate_master()
    build_icns(master)


if __name__ == "__main__":
    main()
