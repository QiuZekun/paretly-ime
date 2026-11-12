#!/usr/bin/env python3
"""Print and check AppIcon.icns sizes in a built Paretly bundle.

macOS picks an icon by OSType. ic14 is the 256 pt @2x image and must be a
512x512 PNG. A 16x16 PNG stored there is scaled up and looks blurred.

When iconutil and sips are on PATH (the macOS CI runner), also expand the
icns and print each iconset image's pixel size. Pass a .app to check the
input method and, when present, the Launchpad app packed in
Contents/Resources/ParetlyLauncher.tar. A bare .icns path is checked too.
"""

from __future__ import annotations

import plistlib
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

# Keep in step with ICNS_TYPES in resources/icons/generate.py.
REQUIRED = {
    "icp4": 16,
    "icp5": 32,
    "icp6": 64,
    "ic07": 128,
    "ic08": 256,
    "ic09": 512,
    "ic10": 1024,
    "ic11": 32,
    "ic12": 64,
    "ic13": 256,
    "ic14": 512,
}

ICONSET_FILES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("usage: inspect-icns.py Paretly.app [AppIcon.icns ...]")
    for raw in sys.argv[1:]:
        path = Path(raw)
        if path.suffix == ".app" or path.name.endswith(".app"):
            check_app(path)
        elif path.suffix == ".icns":
            check_icns(path, label=str(path))
        else:
            raise SystemExit(f"expected a .app or .icns, got {path}")


def check_app(app: Path) -> None:
    icns = app / "Contents" / "Resources" / "AppIcon.icns"
    check_icns(icns, label=f"{app.name} (input method)" if "Launcher" not in app.name else app.name)
    plist = app / "Contents" / "Info.plist"
    if plist.is_file():
        check_icon_name(plist)
    tar_path = app / "Contents" / "Resources" / "ParetlyLauncher.tar"
    if not tar_path.is_file():
        return
    with tempfile.TemporaryDirectory() as tmp:
        with tarfile.open(tar_path) as archive:
            if hasattr(tarfile, "data_filter"):
                archive.extractall(tmp, filter="data")
            else:
                archive.extractall(tmp)
        launcher = Path(tmp) / "Paretly.app"
        launcher_icns = launcher / "Contents" / "Resources" / "AppIcon.icns"
        check_icns(launcher_icns, label="Launchpad /Applications/Paretly.app")
        check_icon_name(launcher / "Contents" / "Info.plist")


def check_icon_name(plist_path: Path) -> None:
    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)
    icon_file = plist.get("CFBundleIconFile")
    if icon_file not in ("AppIcon", "AppIcon.icns"):
        raise SystemExit(f"{plist_path} CFBundleIconFile is {icon_file!r}")
    print(f"CFBundleIconFile={icon_file}")


def check_icns(path: Path, label: str) -> None:
    data = path.read_bytes()
    if data[:4] != b"icns":
        raise SystemExit(f"{path} is not an icns")
    total = struct.unpack_from(">I", data, 4)[0]
    if total != len(data):
        raise SystemExit(f"{path} size header does not match the file")
    print(f"\n{label}")
    print(f"file: {path} ({len(data)} bytes)")
    found: dict[str, tuple[int, int]] = {}
    cursor = 8
    while cursor < len(data):
        ostype = data[cursor : cursor + 4].decode("ascii")
        size = struct.unpack_from(">I", data, cursor + 4)[0]
        payload = data[cursor + 8 : cursor + size]
        if payload[:8] == b"\x89PNG\r\n\x1a\n":
            width, height = struct.unpack_from(">II", payload, 16)
            found[ostype] = (width, height)
            print(f"  {ostype}  {width}x{height}  png")
        else:
            print(f"  {ostype}  {size - 8} bytes  not a png")
        cursor += size
    missing = [ostype for ostype in REQUIRED if ostype not in found]
    mismatched = [
        f"{ostype} is {found[ostype][0]}x{found[ostype][1]}, expected {pixels}x{pixels}"
        for ostype, pixels in REQUIRED.items()
        if ostype in found and found[ostype] != (pixels, pixels)
    ]
    if missing or mismatched:
        raise SystemExit(f"{label} icon sizes are wrong: missing {missing} mismatched {mismatched}")
    roundtrip_with_iconutil(path)


def roundtrip_with_iconutil(path: Path) -> None:
    iconutil = shutil.which("iconutil")
    if iconutil is None:
        print("iconutil not on PATH; PNG sizes above were read from the icns")
        return
    sips = shutil.which("sips")
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        subprocess.run([iconutil, "-c", "iconset", str(path), "-o", str(iconset)], check=True)
        print("iconutil -c iconset:")
        seen: dict[str, tuple[int, int]] = {}
        for image in sorted(iconset.glob("*.png")):
            if sips:
                report = sips_report(image)
                print(report.rstrip())
                width, height = parse_sips(report, image.name)
            else:
                width, height = png_file_size(image)
                print(f"  {image.name}  {width}x{height}")
            seen[image.name] = (width, height)
        missing = [name for name in ICONSET_FILES if name not in seen]
        mismatched = [
            f"{name} is {seen[name][0]}x{seen[name][1]}, expected {pixels}"
            for name, pixels in ICONSET_FILES.items()
            if name in seen and seen[name] != (pixels, pixels)
        ]
        if missing or mismatched:
            raise SystemExit(f"iconutil sizes for {path.name} are wrong: missing {missing} mismatched {mismatched}")


def sips_report(path: Path) -> str:
    result = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def parse_sips(report: str, name: str) -> tuple[int, int]:
    width = height = None
    for line in report.splitlines():
        if "pixelWidth:" in line:
            width = int(line.split(":")[-1].strip())
        elif "pixelHeight:" in line:
            height = int(line.split(":")[-1].strip())
    if width is None or height is None:
        raise SystemExit(f"sips did not report a size for {name}: {report}")
    return width, height


def png_file_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    return struct.unpack_from(">II", data, 16)


if __name__ == "__main__":
    main()
