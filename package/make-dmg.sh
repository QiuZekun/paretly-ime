#!/usr/bin/env bash
# Wrap the unsigned installer package in a disk image.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pkg="${root}/package/Paretly.pkg"
if [[ ! -f "${pkg}" ]]; then
  echo "Missing ${pkg}. Run: make package" >&2
  exit 1
fi

stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT
cp "${pkg}" "${stage}/Paretly.pkg"
cat > "${stage}/安装说明.txt" << 'EOF'
打开 Paretly.pkg 安装。
输入法会装到 /Library/Input Methods/Paretly.app。

这个安装包没有签名，也没有公证。如果系统拦截：
系统设置 > 隐私与安全性 > 仍要打开
或在 Paretly.pkg 上按住 Control 点按，选择「打开」。

装好后如果菜单栏没有 Paretly：
系统设置 > 键盘 > 输入法 > 添加，选择简体中文或繁体中文下的 Paretly。

重新部署：
"/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --reload
EOF

mkdir -p "${root}/dist"
rm -f "${root}/dist/Paretly-unsigned.dmg"
hdiutil create \
  -volname "Paretly" \
  -srcfolder "${stage}" \
  -ov \
  -format UDZO \
  "${root}/dist/Paretly-unsigned.dmg"
ls -lh "${root}/dist/Paretly-unsigned.dmg"
