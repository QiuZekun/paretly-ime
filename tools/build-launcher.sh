#!/usr/bin/env bash
# Build the Launchpad app and store it inside the input method as a tar.
# postinstall unpacks that tar to /Applications/Paretly.app.
#
# The launcher is not a nested .app in the payload. pkgbuild would otherwise
# treat it as a second bundle and try to relocate it.

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-launcher.sh needs macOS (swiftc, lipo, plutil)." >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?usage: build-launcher.sh /path/to/Paretly.app}"
plist="${app}/Contents/Info.plist"

if [[ ! -d "${app}/Contents/MacOS" ]]; then
  echo "Not an app bundle: ${app}" >&2
  exit 1
fi

# A heredoc inside $(...) breaks on the bash 3.2 that ships with macOS.
version="$(python3 "${root}/tools/check-bundle-icons.py" "${plist}")"
test -f "${app}/Contents/Resources/AppIcon.icns"
test -f "${app}/Contents/Resources/paretly.tiff"
test -f "${app}/Contents/Resources/paretly.pdf"
test -f "${app}/Contents/Resources/Assets.car"

archs="${ARCHS:-$(uname -m)}"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT

bins=()
for arch in ${archs}; do
  swiftc -O -sdk "${sdk}" -target "${arch}-apple-macos13.0" -swift-version 5 \
    -framework AppKit \
    -o "${stage}/ParetlyLauncher-${arch}" \
    "${root}/launcher/main.swift"
  bins+=("${stage}/ParetlyLauncher-${arch}")
done

dest="${stage}/Paretly.app"
mkdir -p "${dest}/Contents/MacOS" "${dest}/Contents/Resources"
if [[ "${#bins[@]}" -eq 1 ]]; then
  cp "${bins[0]}" "${dest}/Contents/MacOS/ParetlyLauncher"
else
  lipo -create "${bins[@]}" -output "${dest}/Contents/MacOS/ParetlyLauncher"
fi
chmod 755 "${dest}/Contents/MacOS/ParetlyLauncher"

if [[ "${archs}" == *"arm64"* && "${archs}" == *"x86_64"* ]]; then
  info="$(lipo -info "${dest}/Contents/MacOS/ParetlyLauncher")"
  echo "${info}"
  echo "${info}" | grep -q "arm64"
  echo "${info}" | grep -q "x86_64"
fi

cp "${root}/resources/AppIcon.icns" "${dest}/Contents/Resources/AppIcon.icns"
for lang in en zh-Hans zh-Hant; do
  mkdir -p "${dest}/Contents/Resources/${lang}.lproj"
  {
    printf '\377\376'
    iconv -f UTF-8 -t UTF-16LE "${root}/launcher/${lang}.lproj/Localizable.strings"
  } > "${dest}/Contents/Resources/${lang}.lproj/Localizable.strings"
done

cat > "${dest}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Paretly</string>
	<key>CFBundleExecutable</key>
	<string>ParetlyLauncher</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>com.qiuzekun.inputmethod.Paretly.Launcher</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>en</string>
		<string>zh-Hans</string>
		<string>zh-Hant</string>
	</array>
	<key>CFBundleName</key>
	<string>Paretly</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${version}</string>
	<key>CFBundleVersion</key>
	<string>${version}</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

plutil -lint "${dest}/Contents/Info.plist" >/dev/null
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "${dest}/Contents/Info.plist")" = "Paretly"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${dest}/Contents/Info.plist")" = "ParetlyLauncher"
if /usr/libexec/PlistBuddy -c 'Print :LSUIElement' "${dest}/Contents/Info.plist" >/dev/null 2>&1; then
  echo "Launcher must not set LSUIElement; Launchpad would hide it." >&2
  exit 1
fi

mkdir -p "${app}/Contents/Resources"
tar -cf "${app}/Contents/Resources/ParetlyLauncher.tar" -C "${stage}" Paretly.app
test -f "${app}/Contents/Resources/ParetlyLauncher.tar"
echo "Packed Launchpad app into ${app}/Contents/Resources/ParetlyLauncher.tar"
