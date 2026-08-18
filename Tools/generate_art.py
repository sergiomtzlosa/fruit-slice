#!/usr/bin/env python3
"""Generate original, stylized fruit and background art for Fruit Slice."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "FruitNinja" / "Resources" / "Art"
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 512
SS = 2
R = SIZE * SS
rng = random.Random(0xF17A1)

FRUITS = ["watermelon", "orange", "apple", "pineapple", "kiwi", "dragonfruit"]


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img, "RGBA")


def detail_layer() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    """A separate layer for translucent detail. Drawing directly onto an RGBA
    canvas replaces the destination alpha instead of blending, which would
    punch holes through the fruit flesh."""
    layer = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    return layer, ImageDraw.Draw(layer, "RGBA")


def apply_details(img: Image.Image, detail: Image.Image) -> None:
    """Blend a detail layer onto the fruit without growing its silhouette."""
    mask = img.getchannel("A")
    detail = detail.copy()
    detail.putalpha(ImageChops.multiply(detail.getchannel("A"), mask))
    img.alpha_composite(detail)


def finish(img: Image.Image, name: str,
           rim_color: tuple[int, int, int] = (214, 255, 245)) -> None:
    # Add a subtle inner rim light so fruit silhouettes stay readable against
    # both the dark menu and a bright, busy camera feed.
    alpha = img.getchannel("A")
    # Only rim the opaque fruit, not its soft drop shadow.
    core = alpha.point(lambda value: 255 if value > 200 else 0)
    eroded = core.filter(ImageFilter.MinFilter(19))
    edge = ImageChops.subtract(core, eroded)
    edge = edge.point(lambda value: int(value * 0.62))
    rim = Image.new("RGBA", img.size, (*rim_color, 0))
    rim.putalpha(edge)
    rim = rim.filter(ImageFilter.GaussianBlur(1.4 * SS))
    img = img.copy()
    img.alpha_composite(rim)
    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    img.save(OUT / f"{name}.png")


def shadow(img: Image.Image, cx: float, cy: float, rx: float, ry: float) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(0, 0, 0, 105))
    layer = layer.filter(ImageFilter.GaussianBlur(22 * SS))
    img.alpha_composite(layer)


def soft_highlight(img: Image.Image, cx: float, cy: float, radius: float,
                   color: tuple[int, int, int, int]) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 14
    for i in range(steps, 0, -1):
        t = i / steps
        rr = radius * t
        a = int(color[3] * (1 - t) ** 1.5)
        d.ellipse((cx - rr, cy - rr * 0.75, cx + rr, cy + rr * 0.75),
                  fill=(color[0], color[1], color[2], a))
    layer = layer.filter(ImageFilter.GaussianBlur(8 * SS))
    img.alpha_composite(layer)


def leaf(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, angle: float,
         dark: tuple[int, int, int, int], light: tuple[int, int, int, int]) -> None:
    pts = [(0, -0.55), (0.55, -0.05), (0, 0.55), (-0.55, -0.05)]
    ca, sa = math.cos(angle), math.sin(angle)
    transformed = []
    for x, y in pts:
        transformed.append((cx + (x * ca - y * sa) * s, cy + (x * sa + y * ca) * s))
    d.polygon(transformed, fill=dark)
    inner = [(cx + (x * 0.75 * ca - y * 0.75 * sa) * s,
              cy + (x * 0.75 * sa + y * 0.75 * ca) * s) for x, y in pts]
    d.polygon(inner, fill=light)
    d.line(transformed[0] + transformed[2], fill=(30, 70, 36, 190), width=max(2, int(3 * SS)))


def radial_gradient(size: int, inner: tuple[int, int, int], outer: tuple[int, int, int],
                    center: tuple[float, float] = (0.5, 0.5)) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy = center[0] * size, center[1] * size
    max_d = math.hypot(max(cx, size - cx), max(cy, size - cy))
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / max_d) ** 1.5
            px[x, y] = tuple(int(inner[i] * (1 - t) + outer[i] * t) for i in range(3))
    return img


def watermelon_whole() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.83, R * 0.36, R * 0.08)
    box = (R * 0.18, R * 0.2, R * 0.82, R * 0.84)
    d.ellipse(box, fill=(42, 147, 74, 255))
    body_mask = Image.new("L", (R, R), 0)
    ImageDraw.Draw(body_mask).ellipse(box, fill=255)
    detail = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    dd = ImageDraw.Draw(detail)
    # stripes, clipped to the watermelon silhouette
    for k in range(-3, 4):
        x = R / 2 + k * R * 0.082
        amp = R * 0.025 * (1 - abs(k) / 4.5)
        pts = []
        for i in range(49):
            t = i / 48
            y = R * 0.22 + t * R * 0.6
            xx = x + math.sin(t * math.pi * 1.4 + k) * amp
            pts.append((xx, y))
        dd.line(pts, fill=(22, 92, 47, 220), width=max(3, int(7 * SS)), joint="curve")
    soft_highlight(detail, R * 0.35, R * 0.35, R * 0.2, (190, 255, 205, 105))
    detail.putalpha(ImageChops.multiply(detail.getchannel("A"), body_mask))
    img.alpha_composite(detail)
    d = ImageDraw.Draw(img, "RGBA")
    # stem
    d.line((R * 0.53, R * 0.22, R * 0.58, R * 0.12), fill=(79, 111, 45, 255),
           width=max(4, int(10 * SS)))
    leaf(d, R * 0.63, R * 0.14, R * 0.1, -0.5, (40, 103, 55, 255), (75, 156, 75, 255))
    finish(img, "fruit_watermelon")


def orange_whole() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.85, R * 0.33, R * 0.07)
    d.ellipse((R * 0.18, R * 0.2, R * 0.82, R * 0.84), fill=(255, 157, 40, 255))
    d.ellipse((R * 0.215, R * 0.235, R * 0.785, R * 0.805), fill=(255, 174, 56, 255))
    for _ in range(150):
        a = rng.random() * math.tau
        rr = math.sqrt(rng.random()) * R * 0.27
        x = R / 2 + math.cos(a) * rr
        y = R * 0.52 + math.sin(a) * rr * 0.94
        d.ellipse((x - 1.4 * SS, y - 1.4 * SS, x + 1.4 * SS, y + 1.4 * SS),
                  fill=(205, 103, 19, 100))
    soft_highlight(img, R * 0.36, R * 0.34, R * 0.18, (255, 231, 168, 110))
    d.ellipse((R * 0.45, R * 0.19, R * 0.58, R * 0.235), fill=(72, 111, 44, 255))
    d.line((R * 0.51, R * 0.2, R * 0.52, R * 0.13), fill=(77, 59, 35, 255), width=int(7 * SS))
    leaf(d, R * 0.58, R * 0.17, R * 0.1, -0.2, (44, 108, 55, 255), (91, 174, 81, 255))
    finish(img, "fruit_orange")


def apple_whole() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.85, R * 0.33, R * 0.07)
    base = (224, 48, 66, 255)
    d.ellipse((R * 0.17, R * 0.25, R * 0.55, R * 0.82), fill=base)
    d.ellipse((R * 0.45, R * 0.25, R * 0.83, R * 0.82), fill=(238, 58, 73, 255))
    d.ellipse((R * 0.24, R * 0.42, R * 0.76, R * 0.86), fill=(212, 42, 60, 255))
    d.ellipse((R * 0.28, R * 0.33, R * 0.52, R * 0.62), fill=(245, 104, 106, 185))
    d.ellipse((R * 0.22, R * 0.47, R * 0.48, R * 0.83), fill=base)
    d.ellipse((R * 0.52, R * 0.47, R * 0.78, R * 0.83), fill=(232, 55, 70, 255))
    d.ellipse((R * 0.36, R * 0.28, R * 0.65, R * 0.4), fill=(172, 30, 47, 90))
    soft_highlight(img, R * 0.36, R * 0.39, R * 0.15, (255, 200, 190, 110))
    d.line((R * 0.5, R * 0.28, R * 0.52, R * 0.13), fill=(88, 57, 31, 255),
           width=max(4, int(8 * SS)))
    leaf(d, R * 0.6, R * 0.18, R * 0.11, -0.45, (42, 105, 52, 255), (93, 175, 76, 255))
    finish(img, "fruit_apple")


def pineapple_whole() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.86, R * 0.27, R * 0.06)
    # crown
    for i, angle in enumerate([-1.45, -1.15, -0.85, -0.55, -0.25, 0.05, 0.35]):
        x0, y0 = R * 0.5, R * 0.38
        length = R * (0.21 + 0.03 * (i % 3))
        x1 = x0 + math.cos(angle - math.pi / 2) * length * 0.65
        y1 = y0 - abs(math.sin(angle)) * length
        d.polygon([(x0 - 16 * SS, y0), (x1, y1), (x0 + 16 * SS, y0)],
                  fill=(50, 125, 64, 255) if i % 2 else (78, 154, 75, 255))
    # body
    body = (R * 0.27, R * 0.34, R * 0.73, R * 0.85)
    d.ellipse(body, fill=(230, 162, 43, 255))
    d.ellipse((R * 0.3, R * 0.36, R * 0.7, R * 0.83), fill=(255, 197, 72, 255))
    # cross hatch, clipped to the body ellipse
    hatch = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hatch)
    for k in range(-6, 7):
        x0 = R * 0.5 + k * R * 0.07
        hd.line((x0 - R * 0.17, R * 0.39, x0 + R * 0.1, R * 0.82),
                fill=(163, 104, 28, 150), width=max(2, int(4 * SS)))
        hd.line((x0 - R * 0.1, R * 0.39, x0 + R * 0.17, R * 0.82),
                fill=(255, 226, 137, 115), width=max(2, int(3 * SS)))
    mask = Image.new("L", (R, R), 0)
    ImageDraw.Draw(mask).ellipse((R * 0.3, R * 0.36, R * 0.7, R * 0.83), fill=255)
    hatch.putalpha(ImageChops.multiply(hatch.getchannel("A"), mask))
    img.alpha_composite(hatch)
    d = ImageDraw.Draw(img, "RGBA")
    soft_highlight(img, R * 0.37, R * 0.49, R * 0.1, (255, 242, 175, 105))
    finish(img, "fruit_pineapple")


def kiwi_whole() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.84, R * 0.32, R * 0.065)
    d.ellipse((R * 0.18, R * 0.25, R * 0.82, R * 0.81), fill=(174, 120, 63, 255))
    d.ellipse((R * 0.215, R * 0.285, R * 0.785, R * 0.775), fill=(205, 151, 82, 255))
    for _ in range(420):
        a = rng.random() * math.tau
        rr = math.sqrt(rng.random()) * R * 0.27
        x = R / 2 + math.cos(a) * rr
        y = R * 0.53 + math.sin(a) * rr * 0.9
        c = 86 if rng.random() < 0.5 else 205
        d.ellipse((x - 2 * SS, y - 2 * SS, x + 2 * SS, y + 2 * SS),
                  fill=(c, int(c * 0.66), int(c * 0.34), 75))
    soft_highlight(img, R * 0.36, R * 0.37, R * 0.16, (255, 231, 190, 75))
    d.ellipse((R * 0.48, R * 0.25, R * 0.56, R * 0.3), fill=(94, 67, 38, 255))
    finish(img, "fruit_kiwi")


def dragonfruit_whole() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.84, R * 0.31, R * 0.065)
    d.ellipse((R * 0.19, R * 0.24, R * 0.81, R * 0.83), fill=(208, 41, 130, 255))
    d.ellipse((R * 0.23, R * 0.28, R * 0.77, R * 0.79), fill=(237, 72, 155, 255))
    # scales
    for i in range(8):
        a = -0.8 + i * 0.42
        cx = R * 0.5 + math.sin(a) * R * 0.28
        cy = R * 0.55 + math.cos(a + 1.1) * R * 0.24
        s = R * (0.055 + 0.012 * (i % 3))
        pts = [(cx, cy - s * 1.5), (cx + s, cy + s * 0.5), (cx + s * 0.3, cy + s * 1.3),
               (cx - s * 0.8, cy + s * 0.6)]
        d.polygon(pts, fill=(112, 190, 88, 255))
        d.line(pts + [pts[0]], fill=(59, 128, 62, 190), width=max(2, int(3 * SS)))
    soft_highlight(img, R * 0.35, R * 0.34, R * 0.16, (255, 188, 226, 110))
    finish(img, "fruit_dragonfruit")


def watermelon_half() -> None:
    img, d = canvas()
    d.pieslice((R * 0.1, R * 0.16, R * 0.9, R * 0.9), 180, 360, fill=(42, 146, 74, 255))
    d.pieslice((R * 0.145, R * 0.205, R * 0.855, R * 0.845), 180, 360, fill=(174, 236, 146, 255))
    d.pieslice((R * 0.2, R * 0.26, R * 0.8, R * 0.79), 180, 360, fill=(255, 89, 103, 255))
    for angle in [-2.65, -2.2, -1.6, -1.0, -0.5]:
        cx = R * 0.5 + math.cos(angle) * R * 0.2
        cy = R * 0.52 - abs(math.sin(angle)) * R * 0.13
        d.ellipse((cx - 5 * SS, cy - 8 * SS, cx + 5 * SS, cy + 8 * SS), fill=(28, 24, 26, 255))
    detail, dd = detail_layer()
    dd.arc((R * 0.1, R * 0.16, R * 0.9, R * 0.9), 180, 360,
           fill=(15, 75, 39, 235), width=max(3, int(6 * SS)))
    apply_details(img, detail)
    soft_highlight(img, R * 0.34, R * 0.44, R * 0.13, (255, 200, 206, 85))
    finish(img, "fruit_watermelon_half")


def orange_half() -> None:
    img, d = canvas()
    d.pieslice((R * 0.13, R * 0.14, R * 0.87, R * 0.88), 180, 360, fill=(255, 153, 36, 255))
    d.pieslice((R * 0.17, R * 0.18, R * 0.83, R * 0.84), 180, 360, fill=(255, 178, 64, 255))
    d.pieslice((R * 0.22, R * 0.23, R * 0.78, R * 0.79), 180, 360, fill=(255, 215, 119, 255))
    detail, dd = detail_layer()
    cx, cy = R * 0.5, R * 0.515
    for angle in [0.3, 0.7, 1.1, 1.5, 1.9, 2.3, 2.7]:
        dd.line((cx, cy, cx + math.cos(angle) * R * 0.29, cy - math.sin(angle) * R * 0.29),
                fill=(250, 183, 78, 185), width=max(2, int(4 * SS)))
    # segment highlight
    dd.pieslice((R * 0.31, R * 0.29, R * 0.67, R * 0.56), 195, 330, fill=(255, 238, 178, 70))
    apply_details(img, detail)
    finish(img, "fruit_orange_half")


def apple_half() -> None:
    img, d = canvas()
    d.pieslice((R * 0.14, R * 0.15, R * 0.86, R * 0.88), 180, 360, fill=(226, 47, 65, 255))
    d.pieslice((R * 0.18, R * 0.19, R * 0.82, R * 0.84), 180, 360, fill=(250, 233, 195, 255))
    d.pieslice((R * 0.23, R * 0.24, R * 0.77, R * 0.79), 180, 360, fill=(255, 248, 222, 255))
    detail, dd = detail_layer()
    # core
    dd.pieslice((R * 0.41, R * 0.41, R * 0.59, R * 0.6), 180, 360, fill=(240, 217, 170, 200))
    apply_details(img, detail)
    for dx in [-0.045, 0.045]:
        cx, cy = R * (0.5 + dx), R * 0.43
        d.ellipse((cx - 5 * SS, cy - 8 * SS, cx + 5 * SS, cy + 8 * SS), fill=(91, 63, 28, 255))
    soft_highlight(img, R * 0.34, R * 0.42, R * 0.1, (255, 255, 235, 95))
    finish(img, "fruit_apple_half")


def pineapple_half() -> None:
    img, d = canvas()
    d.pieslice((R * 0.13, R * 0.14, R * 0.87, R * 0.9), 180, 360, fill=(202, 132, 30, 255))
    d.pieslice((R * 0.19, R * 0.2, R * 0.81, R * 0.84), 180, 360, fill=(247, 201, 84, 255))
    d.pieslice((R * 0.24, R * 0.25, R * 0.76, R * 0.78), 180, 360, fill=(255, 220, 107, 255))
    d.pieslice((R * 0.43, R * 0.43, R * 0.57, R * 0.57), 180, 360, fill=(239, 191, 81, 255))
    detail, dd = detail_layer()
    for r in [0.32, 0.25]:
        for angle in [0.35, 0.8, 1.25, 1.7, 2.15, 2.6]:
            cx = R * 0.5 + math.cos(angle) * R * r
            cy = R * 0.52 - math.sin(angle) * R * r
            dd.ellipse((cx - 3.5 * SS, cy - 3.5 * SS, cx + 3.5 * SS, cy + 3.5 * SS),
                       fill=(214, 154, 46, 155))
    apply_details(img, detail)
    finish(img, "fruit_pineapple_half")


def kiwi_half() -> None:
    img, d = canvas()
    d.pieslice((R * 0.13, R * 0.14, R * 0.87, R * 0.88), 180, 360, fill=(130, 86, 45, 255))
    d.pieslice((R * 0.18, R * 0.19, R * 0.82, R * 0.83), 180, 360, fill=(157, 204, 72, 255))
    d.pieslice((R * 0.23, R * 0.24, R * 0.77, R * 0.78), 180, 360, fill=(184, 224, 104, 255))
    d.pieslice((R * 0.4, R * 0.41, R * 0.6, R * 0.61), 180, 360, fill=(244, 247, 204, 255))
    detail, dd = detail_layer()
    for i in range(22):
        a = 0.22 + i * (2.72 / 21)
        rr = R * (0.2 + (i % 3) * 0.018)
        cx = R * 0.5 + math.cos(a) * rr
        cy = R * 0.51 - math.sin(a) * rr
        dd.ellipse((cx - 3 * SS, cy - 5 * SS, cx + 3 * SS, cy + 5 * SS), fill=(42, 48, 27, 225))
    apply_details(img, detail)
    finish(img, "fruit_kiwi_half")


def dragonfruit_half() -> None:
    img, d = canvas()
    d.pieslice((R * 0.14, R * 0.15, R * 0.86, R * 0.88), 180, 360, fill=(205, 40, 126, 255))
    d.pieslice((R * 0.19, R * 0.2, R * 0.81, R * 0.83), 180, 360, fill=(249, 239, 246, 255))
    detail, dd = detail_layer()
    for i in range(34):
        a = 0.2 + i * (2.74 / 33)
        rr = R * (0.13 + (i % 4) * 0.032)
        cx = R * 0.5 + math.cos(a) * rr
        cy = R * 0.51 - math.sin(a) * rr
        dd.ellipse((cx - 2.2 * SS, cy - 3.2 * SS, cx + 2.2 * SS, cy + 3.2 * SS),
                   fill=(39, 36, 44, 210))
    # green tips from rind
    for angle in [0.45, 1.1, 1.75, 2.4]:
        cx = R * 0.5 + math.cos(angle) * R * 0.36
        cy = R * 0.52 - math.sin(angle) * R * 0.36
        dd.polygon([(cx, cy), (cx + 8 * SS, cy + 14 * SS), (cx - 6 * SS, cy + 12 * SS)],
                   fill=(95, 164, 76, 230))
    apply_details(img, detail)
    finish(img, "fruit_dragonfruit_half")


def bomb() -> None:
    img, d = canvas()
    shadow(img, R / 2, R * 0.84, R * 0.3, R * 0.06)
    d.ellipse((R * 0.19, R * 0.26, R * 0.81, R * 0.84), fill=(25, 30, 38, 255))
    d.ellipse((R * 0.22, R * 0.28, R * 0.78, R * 0.81), fill=(47, 55, 64, 255))
    d.pieslice((R * 0.19, R * 0.33, R * 0.81, R * 0.66), 200, 340, fill=(31, 37, 44, 255))
    soft_highlight(img, R * 0.36, R * 0.38, R * 0.13, (197, 218, 236, 115))
    # metal band
    d.arc((R * 0.21, R * 0.29, R * 0.79, R * 0.8), 205, 335,
          fill=(116, 129, 143, 210), width=max(3, int(7 * SS)))
    # cap
    d.rounded_rectangle((R * 0.44, R * 0.2, R * 0.58, R * 0.29), radius=10 * SS,
                        fill=(107, 117, 131, 255))
    # fuse
    fuse_pts = [(R * 0.51, R * 0.21), (R * 0.58, R * 0.13), (R * 0.64, R * 0.16),
                (R * 0.68, R * 0.1), (R * 0.75, R * 0.14)]
    d.line(fuse_pts, fill=(215, 191, 144, 255), width=max(4, int(7 * SS)), joint="curve")
    for i, (x, y) in enumerate([fuse_pts[-1], (R * 0.78, R * 0.08), (R * 0.72, R * 0.06)]):
        rr = R * (0.035 - i * 0.007)
        d.ellipse((x - rr, y - rr, x + rr, y + rr),
                  fill=(255, 166, 36, 220) if i % 2 else (255, 230, 111, 230))
    finish(img, "bomb", rim_color=(255, 168, 84))


def menu_background() -> None:
    w, h = 1920, 1200
    base = radial_gradient(1200, (17, 46, 57), (5, 10, 22), (0.55, 0.35)).resize((w, h))
    img = base.convert("RGBA")
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # soft neon glows
    for (cx, cy, rad, color) in [
        (w * 0.18, h * 0.22, 360, (38, 208, 172, 55)),
        (w * 0.82, h * 0.72, 480, (233, 72, 128, 36)),
        (w * 0.65, h * 0.12, 280, (255, 196, 80, 24)),
    ]:
        for i in range(10, 0, -1):
            rr = rad * i / 10
            a = int(color[3] * (1 - i / 11) ** 1.4)
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr),
                      fill=(color[0], color[1], color[2], a))
    layer = layer.filter(ImageFilter.GaussianBlur(32))
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    # dojo-ish diagonal lines
    for i in range(-10, 22):
        x = i * 120
        d.line((x, 0, x + 500, h), fill=(255, 255, 255, 10), width=2)
    # giant translucent fruit ring
    d.ellipse((w * 0.66, -h * 0.12, w * 1.2, h * 0.85), outline=(95, 255, 208, 24),
              width=3)
    d.ellipse((w * 0.72, -h * 0.02, w * 1.14, h * 0.75), outline=(255, 255, 255, 12),
              width=2)
    # vignette
    vig = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse((-w * 0.15, -h * 0.2, w * 1.15, h * 1.2), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(200))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 175))
    img = Image.composite(img, dark, vig)
    img.convert("RGB").save(OUT / "menu_background.png", quality=92)


def particle() -> None:
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - c, y - c) / c
            a = max(0, int(255 * max(0.0, 1 - dist) ** 2.2))
            px[x, y] = (255, 255, 255, a)
    img.save(OUT / "spark.png")


def main() -> None:
    watermelon_whole()
    orange_whole()
    apple_whole()
    pineapple_whole()
    kiwi_whole()
    dragonfruit_whole()
    watermelon_half()
    orange_half()
    apple_half()
    pineapple_half()
    kiwi_half()
    dragonfruit_half()
    bomb()
    menu_background()
    particle()
    print(f"Generated art in {OUT}")


if __name__ == "__main__":
    main()
