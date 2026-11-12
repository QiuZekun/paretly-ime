#!/usr/bin/env python3
"""Regenerate Paretly icons from resources/icons/src/*.svg.

Sources (replace these when the final art is ready, then rerun this script):

  resources/icons/src/menu-template.svg
      Menu-bar template on a 256x256 canvas: a black Inter Display ExtraBold P
      centered in (0,0)-(216,256) at 220px, and a caret from (210,40) to
      (230,216). No box. Transparent background.
  resources/icons/src/app-icon.svg
      App icon. Dark vertical gradient squircle, white P, blue bar, and a soft
      shadow, on a 1024x1024 canvas.

Outputs:

  resources/paretly.pdf
      18x18 pt vector template. macOS can scale it without blurring.
  resources/paretly.tiff
      Template bitmaps at 16 pt and 18 pt, each with @1x (72 dpi) and @2x
      (144 dpi). Info.plist points the input-menu keys at this file.
  resources/AppIcon.icns
      Every PNG size macOS reads, stored under the OSType for that size.
      A 16px PNG must not be filed as ic14: Launchpad would scale it up.
  Assets.xcassets/AppIcon.appiconset/
      The same artwork as a macOS app icon set, plus Contents.json.

Each bitmap is rasterized from the SVG at that pixel size (supersampled).
The script never scales a smaller bitmap up. It uses only the Python 3
standard library. SVG support is the subset these sources need: filled paths
with M/L/H/V/C/Z (absolute or relative), even-odd or nonzero fill, a vertical
user-space linearGradient, and a drop shadow written as feGaussianBlur +
feOffset + feFuncA on a group.
"""

from __future__ import annotations

import re
import struct
import zlib
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "resources" / "icons" / "src"
APPICONSET = ROOT / "Assets.xcassets" / "AppIcon.appiconset"

ICONSET_SPECS = (
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
)

# OSTypes iconutil writes for a complete macOS iconset, and the PNG pixel size
# each type must contain. ic11–ic14 are the @2x images (16@2x, 32@2x, 128@2x,
# 256@2x). ic10 is 512@2x. Filing a 16px PNG as ic14 is what made Launchpad
# upscale the icon until it looked blurred.
ICNS_TYPES = (
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
    ("ic11", 32),
    ("ic12", 64),
    ("ic13", 256),
    ("ic14", 512),
)


def main() -> None:
    menu = parse_svg(SRC / "menu-template.svg")
    app = parse_svg(SRC / "app-icon.svg")
    if menu.view_width < 16 or abs(menu.view_width - menu.view_height) > 0.01:
        raise SystemExit("menu-template.svg must use a square viewBox of at least 16")
    if abs(app.view_width - 1024) > 0.01 or abs(app.view_height - 1024) > 0.01:
        raise SystemExit("app-icon.svg must use a 1024x1024 viewBox")

    # 18 pt matches the menu bar. The drawing is vector, so 16 pt slots stay sharp.
    pdf = build_pdf(menu, points=18)
    (ROOT / "resources" / "paretly.pdf").write_bytes(pdf)

    menu_specs = (
        (16, 72),
        (32, 144),
        (18, 72),
        (36, 144),
    )
    tiff = build_tiff(
        tuple(
            (rasterize(menu, pixels, supersample=8), pixels, pixels, (dpi, 1))
            for pixels, dpi in menu_specs
        )
    )
    (ROOT / "resources" / "paretly.tiff").write_bytes(tiff)

    pngs: dict[int, bytes] = {}
    APPICONSET.mkdir(parents=True, exist_ok=True)
    for name, pixels in ICONSET_SPECS:
        if pixels not in pngs:
            sample = 4 if pixels <= 256 else 2
            pngs[pixels] = encode_png(rasterize(app, pixels, supersample=sample))
        (APPICONSET / name).write_bytes(pngs[pixels])
    (APPICONSET / "Contents.json").write_text(contents_json(), encoding="utf-8")
    stale = APPICONSET / "icon_1024.png"
    if stale.exists():
        stale.unlink()

    icns = build_icns({pixels: data for pixels, data in pngs.items()})
    (ROOT / "resources" / "AppIcon.icns").write_bytes(icns)

    verify_pdf(pdf)
    verify_tiff(tiff)
    verify_icns(icns)
    print("Wrote resources/paretly.pdf, resources/paretly.tiff, resources/AppIcon.icns")
    print(f"Wrote {APPICONSET.relative_to(ROOT)} ({len(ICONSET_SPECS)} images)")


class Shape:
    def __init__(self, fill, rule: str, subpaths: list, shadow: tuple[float, float, float, float] | None):
        # fill is ("solid", rgba) or ("vgrad", top_rgba, bottom_rgba, y0, y1)
        # shadow is (dx, dy, sigma, alpha_scale) in user units
        self.fill = fill
        self.rule = rule
        self.subpaths = subpaths
        self.shadow = shadow


class Picture:
    def __init__(self, view_width: float, view_height: float, shapes: list[Shape]):
        self.view_width = view_width
        self.view_height = view_height
        self.shapes = shapes


def _tag(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def parse_svg(path: Path) -> Picture:
    tree = ET.parse(path)
    root = tree.getroot()
    view = root.get("viewBox")
    if not view:
        raise SystemExit(f"{path} needs a viewBox")
    parts = [float(n) for n in view.replace(",", " ").split()]
    if len(parts) != 4 or parts[0] != 0 or parts[1] != 0:
        raise SystemExit(f"{path} viewBox must be '0 0 W H'")
    width, height = parts[2], parts[3]
    gradients: dict[str, tuple] = {}
    filters: dict[str, tuple[float, float, float, float]] = {}
    shapes: list[Shape] = []

    def parse_defs(element: ET.Element) -> None:
        for child in element:
            tag = _tag(child)
            ident = child.get("id")
            if tag == "linearGradient" and ident:
                gradients[ident] = _parse_vertical_gradient(child, height)
            elif tag == "filter" and ident:
                filters[ident] = _parse_shadow_filter(child)

    def walk(element: ET.Element, shadow: tuple[float, float, float, float] | None) -> None:
        for child in element:
            tag = _tag(child)
            if tag == "defs":
                parse_defs(child)
            elif tag == "g":
                next_shadow = shadow
                filt = child.get("filter")
                if filt:
                    if not filt.startswith("url(#") or not filt.endswith(")"):
                        raise SystemExit(f"unsupported filter reference {filt}")
                    next_shadow = filters[filt[5:-1]]
                walk(child, next_shadow)
            elif tag == "path":
                shapes.append(_parse_path_element(child, shadow, gradients))
            elif tag == "title":
                continue
            else:
                raise SystemExit(f"{path} has unsupported <{tag}>")

    walk(root, None)
    if not shapes:
        raise SystemExit(f"{path} has no paths")
    return Picture(width, height, shapes)


def _parse_path_element(element: ET.Element, shadow, gradients: dict[str, tuple]) -> Shape:
    fill_attr = element.get("fill", "#000000")
    if fill_attr.startswith("url(#") and fill_attr.endswith(")"):
        fill = gradients[fill_attr[5:-1]]
    else:
        fill = ("solid", parse_color(fill_attr))
    rule = element.get("fill-rule", "nonzero")
    if rule not in ("nonzero", "evenodd"):
        raise SystemExit(f"unsupported fill-rule {rule}")
    data = element.get("d")
    if not data:
        raise SystemExit("path without d")
    return Shape(fill, rule, parse_path(data), shadow)


def _parse_vertical_gradient(element: ET.Element, view_height: float) -> tuple:
    y0 = float(element.get("y1", "0"))
    y1 = float(element.get("y2", str(view_height)))
    stops = []
    for child in element:
        if _tag(child) != "stop":
            continue
        offset = child.get("offset", "0").strip()
        if offset.endswith("%"):
            offset_value = float(offset[:-1]) / 100
        else:
            offset_value = float(offset)
        stops.append((offset_value, parse_color(child.get("stop-color", "#000000"))))
    stops.sort()
    if len(stops) != 2 or abs(stops[0][0]) > 0.001 or abs(stops[1][0] - 1) > 0.001:
        raise SystemExit("gradients must be two stops at 0 and 1")
    return ("vgrad", stops[0][1], stops[1][1], y0, y1)


def _parse_shadow_filter(element: ET.Element) -> tuple[float, float, float, float]:
    sigma = 0.0
    dx = 0.0
    dy = 0.0
    alpha = 1.0
    for child in element:
        tag = _tag(child)
        if tag == "feGaussianBlur":
            sigma = float(child.get("stdDeviation", "0").split()[0])
        elif tag == "feOffset":
            dx = float(child.get("dx", "0"))
            dy = float(child.get("dy", "0"))
        elif tag == "feComponentTransfer":
            for func in child:
                if _tag(func) == "feFuncA" and func.get("type") == "linear":
                    alpha = float(func.get("slope", "1"))
    return (dx, dy, sigma, alpha)


def parse_color(value: str) -> tuple[int, int, int, int]:
    value = value.strip()
    if value.lower() == "black":
        return (0, 0, 0, 255)
    if value.lower() == "white":
        return (255, 255, 255, 255)
    if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
        return (int(value[1:3], 16), int(value[3:5], 16), int(value[5:7], 16), 255)
    raise SystemExit(f"unsupported fill color {value}")


def parse_path(data: str) -> list[list[tuple]]:
    tokens = re.findall(r"[MmLlHhVvCcZz]|[-+]?(?:\d+\.\d+|\d+\.?|\.\d+)", data)
    subpaths: list[list[tuple]] = []
    current: list[tuple] = []
    cx = cy = 0.0
    sx = sy = 0.0
    index = 0
    command = ""

    def number() -> float:
        nonlocal index
        if index >= len(tokens) or not _is_number(tokens[index]):
            raise SystemExit(f"path ended early near {tokens[max(0, index - 1):index + 2]}")
        value = float(tokens[index])
        index += 1
        return value

    while index < len(tokens):
        if not _is_number(tokens[index]):
            command = tokens[index]
            index += 1
        elif command in ("M", "m"):
            command = "L" if command == "M" else "l"
        elif command in ("L", "l", "H", "h", "V", "v", "C", "c"):
            pass
        else:
            raise SystemExit(f"unexpected path token {tokens[index]}")

        relative = command.islower()
        op = command.upper()
        if op == "M":
            if current:
                subpaths.append(current)
            x, y = number(), number()
            if relative:
                x += cx
                y += cy
            cx, cy = x, y
            sx, sy = x, y
            current = [("M", x, y)]
        elif op == "L":
            x, y = number(), number()
            if relative:
                x += cx
                y += cy
            current.append(("L", x, y))
            cx, cy = x, y
        elif op == "H":
            x = number()
            if relative:
                x += cx
            current.append(("L", x, cy))
            cx = x
        elif op == "V":
            y = number()
            if relative:
                y += cy
            current.append(("L", cx, y))
            cy = y
        elif op == "C":
            x1, y1 = number(), number()
            x2, y2 = number(), number()
            x, y = number(), number()
            if relative:
                x1 += cx
                y1 += cy
                x2 += cx
                y2 += cy
                x += cx
                y += cy
            current.append(("C", x1, y1, x2, y2, x, y))
            cx, cy = x, y
        elif op == "Z":
            current.append(("Z", sx, sy))
            cx, cy = sx, sy
            if current:
                subpaths.append(current)
            current = []
        else:
            raise SystemExit(f"unsupported path command {command}")
    if current:
        subpaths.append(current)
    return subpaths


def _is_number(token: str) -> bool:
    return token[:1].isdigit() or token[:1] in "+-." and token not in ("+", "-", ".")


def flatten(subpath: list[tuple], tolerance: float) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for item in subpath:
        if item[0] == "M":
            points.append((item[1], item[2]))
        elif item[0] in ("L", "Z"):
            points.append((item[1], item[2]))
        elif item[0] == "C":
            _, x1, y1, x2, y2, x, y = item
            x0, y0 = points[-1]
            points.extend(_flatten_cubic((x0, y0), (x1, y1), (x2, y2), (x, y), tolerance)[1:])
    return points


def _flatten_cubic(p0, p1, p2, p3, tolerance: float) -> list[tuple[float, float]]:
    if _flat(p0, p1, p2, p3, tolerance):
        return [p0, p3]
    left, right = _split_cubic(p0, p1, p2, p3)
    a = _flatten_cubic(*left, tolerance)
    b = _flatten_cubic(*right, tolerance)
    return a[:-1] + b


def _flat(p0, p1, p2, p3, tolerance: float) -> bool:
    def dist(point) -> float:
        vx, vy = p3[0] - p0[0], p3[1] - p0[1]
        length = (vx * vx + vy * vy) ** 0.5
        if length == 0:
            dx, dy = point[0] - p0[0], point[1] - p0[1]
            return (dx * dx + dy * dy) ** 0.5
        return abs((point[0] - p0[0]) * vy - (point[1] - p0[1]) * vx) / length

    return dist(p1) <= tolerance and dist(p2) <= tolerance


def _split_cubic(p0, p1, p2, p3):
    def mid(a, b):
        return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)

    p01, p12, p23 = mid(p0, p1), mid(p1, p2), mid(p2, p3)
    p012, p123 = mid(p01, p12), mid(p12, p23)
    p0123 = mid(p012, p123)
    return (p0, p01, p012, p0123), (p0123, p123, p23, p3)


def rasterize(picture: Picture, pixels: int, supersample: int) -> bytes:
    size = pixels * supersample
    scale = size / picture.view_width
    if abs(picture.view_width - picture.view_height) > 0.01:
        raise SystemExit("raster icons must be square")
    canvas = bytearray(pixels * pixels * 4)
    tolerance = 0.35 / scale
    user_scale = pixels / picture.view_width
    for shape in picture.shapes:
        if shape.shadow and shape.shadow[2] > 0:
            _composite_shadow(canvas, picture, shape, pixels, user_scale)
        mask = bytearray(size * size)
        polygons = []
        for subpath in shape.subpaths:
            polygon = flatten(subpath, tolerance)
            if len(polygon) >= 2:
                polygons.append([(x * scale, y * scale) for x, y in polygon])
        _fill_mask(mask, size, polygons, shape.rule)
        layer = _downsample_mask(mask, size, pixels, shape.fill, picture.view_height)
        _composite(canvas, layer)
    return bytes(canvas)


def _composite_shadow(canvas: bytearray, picture: Picture, shape: Shape, pixels: int, user_scale: float) -> None:
    dx, dy, sigma, alpha_scale = shape.shadow
    mask = bytearray(pixels * pixels)
    tolerance = 0.35 / user_scale
    polygons = []
    for subpath in shape.subpaths:
        polygon = flatten(subpath, tolerance)
        if len(polygon) >= 2:
            polygons.append([(x * user_scale, y * user_scale) for x, y in polygon])
    _fill_mask(mask, pixels, polygons, shape.rule)
    blurred = _gaussian_blur(mask, pixels, sigma * user_scale)
    shift_x = int(round(dx * user_scale))
    shift_y = int(round(dy * user_scale))
    layer = bytearray(pixels * pixels * 4)
    for y in range(pixels):
        source_y = y - shift_y
        if not 0 <= source_y < pixels:
            continue
        for x in range(pixels):
            source_x = x - shift_x
            if not 0 <= source_x < pixels:
                continue
            coverage = blurred[source_y * pixels + source_x]
            if coverage == 0:
                continue
            layer[(y * pixels + x) * 4 + 3] = int(coverage * alpha_scale + 0.5)
    _composite(canvas, bytes(layer))


def _gaussian_blur(mask: bytearray, size: int, sigma: float) -> bytearray:
    import math
    if sigma <= 0.15:
        return mask
    radius = max(1, int(math.ceil(sigma * 3)))
    kernel = [math.exp(-0.5 * (i / sigma) ** 2) for i in range(-radius, radius + 1)]
    total = sum(kernel)
    kernel = [value / total for value in kernel]
    horizontal = [0.0] * (size * size)
    for y in range(size):
        row = y * size
        for x in range(size):
            acc = 0.0
            for offset, weight in enumerate(kernel):
                sample = x + offset - radius
                if 0 <= sample < size:
                    acc += mask[row + sample] * weight
            horizontal[row + x] = acc
    out = bytearray(size * size)
    for y in range(size):
        for x in range(size):
            acc = 0.0
            for offset, weight in enumerate(kernel):
                sample = y + offset - radius
                if 0 <= sample < size:
                    acc += horizontal[sample * size + x] * weight
            out[y * size + x] = max(0, min(255, int(acc + 0.5)))
    return out


def _fill_mask(mask: bytearray, size: int, polygons: list[list[tuple[float, float]]], rule: str) -> None:
    edges = []
    for polygon in polygons:
        count = len(polygon)
        for index in range(count):
            x0, y0 = polygon[index]
            x1, y1 = polygon[(index + 1) % count]
            if y0 == y1:
                continue
            if y0 < y1:
                edges.append((y0, y1, x0, x1, 1))
            else:
                edges.append((y1, y0, x1, x0, -1))
    for y in range(size):
        sample = y + 0.5
        hits = []
        for y0, y1, x0, x1, winding in edges:
            if y0 <= sample < y1:
                t = (sample - y0) / (y1 - y0)
                hits.append((x0 + (x1 - x0) * t, winding))
        hits.sort(key=lambda item: item[0])
        row = y * size
        if rule == "evenodd":
            for index in range(0, len(hits) - 1, 2):
                _stamp(mask, row, size, hits[index][0], hits[index + 1][0])
        else:
            winding = 0
            for index, (x_pos, direction) in enumerate(hits):
                winding += direction
                if winding != 0 and index + 1 < len(hits):
                    _stamp(mask, row, size, x_pos, hits[index + 1][0])


def _stamp(mask: bytearray, row: int, size: int, start: float, end: float) -> None:
    x0 = max(0, int(start + 0.999999))
    x1 = min(size, int(end))
    if x1 > x0:
        mask[row + x0 : row + x1] = b"\xff" * (x1 - x0)


def _downsample_mask(mask: bytearray, size: int, pixels: int, fill, view_height: float) -> bytes:
    factor = size // pixels
    area = factor * factor
    out = bytearray(pixels * pixels * 4)
    for y in range(pixels):
        red, green, blue = _fill_rgb(fill, (y + 0.5) / pixels * view_height)
        for x in range(pixels):
            total = 0
            base = y * factor * size + x * factor
            for row in range(factor):
                span = base + row * size
                total += mask[span : span + factor].count(255)
            if total == 0:
                continue
            offset = (y * pixels + x) * 4
            out[offset] = red
            out[offset + 1] = green
            out[offset + 2] = blue
            out[offset + 3] = (total * 255 + area // 2) // area
    return bytes(out)


def _fill_rgb(fill, y_user: float) -> tuple[int, int, int]:
    if fill[0] == "solid":
        red, green, blue, _alpha = fill[1]
        return red, green, blue
    _kind, top, bottom, y0, y1 = fill
    span = y1 - y0
    t = 0.0 if span == 0 else (y_user - y0) / span
    t = min(1.0, max(0.0, t))
    return tuple(int(top[channel] * (1 - t) + bottom[channel] * t + 0.5) for channel in range(3))


def _composite(dst: bytearray, src: bytes) -> None:
    for offset in range(0, len(dst), 4):
        src_a = src[offset + 3]
        if src_a == 0:
            continue
        if src_a == 255:
            dst[offset : offset + 4] = src[offset : offset + 4]
            continue
        dst_a = dst[offset + 3]
        out_a = src_a + dst_a * (255 - src_a) // 255
        if out_a == 0:
            continue
        for channel in range(3):
            blended = src[offset + channel] * src_a + dst[offset + channel] * dst_a * (255 - src_a) // 255
            dst[offset + channel] = blended // out_a
        dst[offset + 3] = out_a


def encode_png(rgba: bytes) -> bytes:
    pixels = int((len(rgba) / 4) ** 0.5)
    if pixels * pixels * 4 != len(rgba):
        raise SystemExit("PNG buffer is not square")

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = bytearray()
    stride = pixels * 4
    for y in range(pixels):
        raw.append(0)
        raw.extend(rgba[y * stride : (y + 1) * stride])
    ihdr = struct.pack(">IIBBBBB", pixels, pixels, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def build_pdf(picture: Picture, points: float | None = None) -> bytes:
    if abs(picture.view_width - picture.view_height) > 0.01:
        raise SystemExit("PDF icons must be square")
    page = picture.view_width if points is None else points
    scale = page / picture.view_width

    def xy(x: float, y: float) -> str:
        return f"{x * scale:.3f} {page - y * scale:.3f}"

    commands = ["0 0 0 RG", "0 0 0 rg"]
    for shape in picture.shapes:
        if shape.fill[0] != "solid":
            raise SystemExit("PDF export only supports solid fills")
        red, green, blue, _alpha = shape.fill[1]
        commands.append(f"{red / 255:.4f} {green / 255:.4f} {blue / 255:.4f} rg")
        for subpath in shape.subpaths:
            for index, item in enumerate(subpath):
                if item[0] == "M":
                    commands.append(f"{xy(item[1], item[2])} m")
                elif item[0] in ("L", "Z"):
                    commands.append(f"{xy(item[1], item[2])} l")
                elif item[0] == "C":
                    _, x1, y1, x2, y2, x, y = item
                    commands.append(f"{xy(x1, y1)} {xy(x2, y2)} {xy(x, y)} c")
                if item[0] == "Z" or (index == len(subpath) - 1 and item[0] != "Z"):
                    commands.append("h")
        commands.append("f*" if shape.rule == "evenodd" else "f")
    stream = "\n".join(commands).encode("ascii") + b"\n"
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Count 1 /Kids [3 0 R] >>",
        (
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {page:.2f} {page:.2f}] "
            "/Resources << /ProcSet [/PDF] >> "
            "/Group << /Type /Group /S /Transparency /CS /DeviceRGB /I true >> "
            "/Contents 4 0 R >>"
        ).encode("ascii"),
        b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n" + stream + b"endstream",
    ]
    body = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for number, obj in enumerate(objects, start=1):
        offsets.append(len(body))
        body.extend(f"{number} 0 obj\n".encode("ascii"))
        body.extend(obj)
        body.extend(b"\nendobj\n")
    xref = len(body)
    body.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    body.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        body.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    body.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode("ascii")
    )
    return bytes(body)


def build_tiff(images: tuple[tuple[bytes, int, int, tuple[int, int]], ...]) -> bytes:
    # Classic little-endian TIFF. 16 px at 72 dpi is 16 pt @1x; 32 px at 144 dpi
    # is 16 pt @2x. 18 px / 36 px are the 18 pt pair. ExtraSamples 2 is straight alpha.
    for rgba, width, height, _dpi in images:
        if len(rgba) != width * height * 4:
            raise SystemExit("TIFF image has the wrong number of bytes")
    return _write_tiff_ifds(images)


def _write_tiff_ifds(images: tuple[tuple[bytes, int, int, tuple[int, int]], ...]) -> bytes:
    records = []
    for rgba, width, height, (dpi_num, dpi_den) in images:
        records.append(
            {
                "rgba": rgba,
                "width": width,
                "height": height,
                "dpi_num": dpi_num,
                "dpi_den": dpi_den,
            }
        )
    blob = bytearray(b"II*\x00" + b"\x00\x00\x00\x00")
    ifd_offsets = []
    for record in records:
        ifd_offsets.append(len(blob))
        record["bits_at"] = None
        record["xres_at"] = None
        record["yres_at"] = None
        record["strip_at"] = None
        # Placeholder IFD; fill after we know where the overflow values live.
        count = 14
        ifd_size = 2 + count * 12 + 4
        record["ifd_at"] = len(blob)
        blob.extend(b"\x00" * ifd_size)
        record["bits_at"] = len(blob)
        blob.extend(struct.pack("<HHHH", 8, 8, 8, 8))
        record["xres_at"] = len(blob)
        blob.extend(struct.pack("<II", record["dpi_num"], record["dpi_den"]))
        record["yres_at"] = len(blob)
        blob.extend(struct.pack("<II", record["dpi_num"], record["dpi_den"]))
        record["strip_at"] = len(blob)
        blob.extend(record["rgba"])
    for index, record in enumerate(records):
        entries = [
            (256, 3, 1, record["width"]),
            (257, 3, 1, record["height"]),
            (258, 3, 4, record["bits_at"]),
            (259, 3, 1, 1),
            (262, 3, 1, 2),
            (273, 4, 1, record["strip_at"]),
            (277, 3, 1, 4),
            (278, 4, 1, record["height"]),
            (279, 4, 1, len(record["rgba"])),
            (282, 5, 1, record["xres_at"]),
            (283, 5, 1, record["yres_at"]),
            (284, 3, 1, 1),
            (296, 3, 1, 2),
            (338, 3, 1, 2),
        ]
        next_ifd = ifd_offsets[index + 1] if index + 1 < len(records) else 0
        encoded = struct.pack("<H", len(entries))
        for tag, typ, count, value in entries:
            encoded += struct.pack("<HHI", tag, typ, count)
            if typ == 3 and count == 1:
                encoded += struct.pack("<HH", value, 0)
            else:
                encoded += struct.pack("<I", value)
        encoded += struct.pack("<I", next_ifd)
        blob[record["ifd_at"] : record["ifd_at"] + len(encoded)] = encoded
    struct.pack_into("<I", blob, 4, ifd_offsets[0])
    return bytes(blob)


def build_icns(pngs: dict[int, bytes]) -> bytes:
    body = bytearray()
    for ostype, pixels in ICNS_TYPES:
        data = pngs[pixels]
        body.extend(ostype.encode("ascii"))
        body.extend(struct.pack(">I", 8 + len(data)))
        body.extend(data)
    return b"icns" + struct.pack(">I", 8 + len(body)) + bytes(body)


def contents_json() -> str:
    images = []
    mapping = (
        ("16x16", "1x", "icon_16x16.png"),
        ("16x16", "2x", "icon_16x16@2x.png"),
        ("32x32", "1x", "icon_32x32.png"),
        ("32x32", "2x", "icon_32x32@2x.png"),
        ("128x128", "1x", "icon_128x128.png"),
        ("128x128", "2x", "icon_128x128@2x.png"),
        ("256x256", "1x", "icon_256x256.png"),
        ("256x256", "2x", "icon_256x256@2x.png"),
        ("512x512", "1x", "icon_512x512.png"),
        ("512x512", "2x", "icon_512x512@2x.png"),
    )
    for size, scale, filename in mapping:
        images.append(
            "    {\n"
            f'      "filename" : "{filename}",\n'
            '      "idiom" : "mac",\n'
            f'      "scale" : "{scale}",\n'
            f'      "size" : "{size}"\n'
            "    }"
        )
    joined = ",\n".join(images)
    return (
        "{\n"
        '  "images" : [\n'
        f"{joined}\n"
        "  ],\n"
        '  "info" : {\n'
        '    "author" : "xcode",\n'
        "    \"version\" : 1\n"
        "  }\n"
        "}\n"
    )


def verify_pdf(data: bytes) -> None:
    text = data.decode("latin1")
    if "/MediaBox [0 0 18.00 18.00]" not in text:
        raise SystemExit("paretly.pdf is not an 18x18 pt page")
    if " 1 1 1 rg" in text or "1.0000 1.0000 1.0000 rg" in text:
        raise SystemExit("paretly.pdf paints a white background")


def verify_tiff(data: bytes) -> None:
    if data[:4] != b"II*\x00":
        raise SystemExit("paretly.tiff is not a little-endian TIFF")
    offset = struct.unpack_from("<I", data, 4)[0]
    seen = []
    while offset:
        count = struct.unpack_from("<H", data, offset)[0]
        tags = {}
        for index in range(count):
            entry = offset + 2 + index * 12
            tag, typ, number, value = struct.unpack_from("<HHII", data, entry)
            tags[tag] = (typ, number, value)
        width = tags[256][2]
        height = tags[257][2]
        xres_at = tags[282][2]
        num, den = struct.unpack_from("<II", data, xres_at)
        seen.append((width, height, num / den))
        offset = struct.unpack_from("<I", data, offset + 2 + count * 12)[0]
    expected = [(16, 16, 72.0), (32, 32, 144.0), (18, 18, 72.0), (36, 36, 144.0)]
    if seen != expected:
        raise SystemExit(f"paretly.tiff representations are {seen}, expected {expected}")


def png_dimensions(data: bytes) -> tuple[int, int]:
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("icns element is not a PNG")
    return struct.unpack_from(">II", data, 16)


def verify_icns(data: bytes) -> None:
    if data[:4] != b"icns":
        raise SystemExit("AppIcon.icns is missing its header")
    total = struct.unpack_from(">I", data, 4)[0]
    if total != len(data):
        raise SystemExit("AppIcon.icns size header does not match the file")
    expected_sizes = {ostype: pixels for ostype, pixels in ICNS_TYPES}
    found = []
    cursor = 8
    while cursor < len(data):
        ostype = data[cursor : cursor + 4].decode("ascii")
        size = struct.unpack_from(">I", data, cursor + 4)[0]
        payload = data[cursor + 8 : cursor + size]
        width, height = png_dimensions(payload)
        expected = expected_sizes.get(ostype)
        if expected is None or (width, height) != (expected, expected):
            raise SystemExit(f"{ostype} holds a {width}x{height} PNG, expected {expected}")
        found.append(ostype)
        cursor += size
    expected_order = [ostype for ostype, _pixels in ICNS_TYPES]
    if found != expected_order:
        raise SystemExit(f"AppIcon.icns types are {found}")


if __name__ == "__main__":
    main()
