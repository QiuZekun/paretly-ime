#!/usr/bin/env python3
"""Check a built Paretly.app Info.plist and print CFBundleShortVersionString.

macOS ships bash 3.2, which mishandles a Python heredoc inside $(...).
Keep this check in its own file so build-launcher.sh can call it directly.
"""

import plistlib
import sys


def main() -> None:
    path = sys.argv[1]
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)
    # Xcode rewrites CFBundleIconFile to the asset-catalog name without ".icns".
    # Either form resolves to Contents/Resources/AppIcon.icns.
    icon_file = plist.get("CFBundleIconFile")
    if icon_file not in ("AppIcon", "AppIcon.icns"):
        sys.exit(f"CFBundleIconFile is {icon_file!r}")
    if plist.get("TISIconIsTemplate") is not True:
        sys.exit(f"TISIconIsTemplate is {plist.get('TISIconIsTemplate')!r}")
    if plist.get("tsInputMethodIconFileKey") != "paretly.tiff":
        sys.exit(f"tsInputMethodIconFileKey is {plist.get('tsInputMethodIconFileKey')!r}")
    connection = plist.get("InputMethodConnectionName")
    if connection != "Paretly_Connection" or "Squirrel" in str(connection):
        sys.exit(f"InputMethodConnectionName is {connection!r}")
    controller = plist.get("InputMethodServerControllerClass")
    delegate = plist.get("InputMethodServerDelegateClass")
    if controller != "ParetlyInputController" or "Squirrel" in str(controller):
        sys.exit(f"InputMethodServerControllerClass is {controller!r}")
    if delegate != "ParetlyInputController" or "Squirrel" in str(delegate):
        sys.exit(f"InputMethodServerDelegateClass is {delegate!r}")
    modes = plist["ComponentInputModeDict"]["tsInputModeListKey"]
    icon_fields = (
        "tsInputModeMenuIconFileKey",
        "tsInputModeAlternateMenuIconFileKey",
        "tsInputModePaletteIconFileKey",
    )
    for key in (
        "com.qiuzekun.inputmethod.Paretly.Hans",
        "com.qiuzekun.inputmethod.Paretly.Hant",
    ):
        if "Squirrel" in key:
            sys.exit(f"input mode id contains Squirrel: {key}")
        mode = modes[key]
        mode_id = mode.get("TISInputSourceID")
        if mode_id != key or "Squirrel" in str(mode_id):
            sys.exit(f"{key} TISInputSourceID is {mode_id!r}")
        if mode.get("TISIconIsTemplate") is not True:
            sys.exit(f"{key} TISIconIsTemplate is {mode.get('TISIconIsTemplate')!r}")
        for field in icon_fields:
            icon = mode.get(field)
            if icon != "paretly.tiff" or "Squirrel" in str(icon):
                sys.exit(f"{key} {field} is {icon!r}")
    version = plist.get("CFBundleShortVersionString") or plist.get("CFBundleVersion")
    if not version or str(version).startswith("$("):
        sys.exit(f"CFBundleShortVersionString is {version!r}")
    print(version)


if __name__ == "__main__":
    main()
