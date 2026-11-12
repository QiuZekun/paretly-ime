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

这个安装包没有签名，也没有公证。公证需要付费的 Apple Developer 账号。
如果系统拦截：
系统设置 > 隐私与安全性 > 仍要打开
或执行：xattr -dr com.apple.quarantine，路径换成这个磁盘镜像或 Paretly.pkg
也可以在 Paretly.pkg 上按住 Control 点按，选择「打开」。

装好后如果菜单栏没有 Paretly：
系统设置 > 键盘 > 输入法 > 添加，选择简体中文或繁体中文下的 Paretly。

启动台里会多一个 Paretly。点它打开「Paretly 设置…」。
输入法本体在 /Library/Input Methods，启动台不列出那个目录。

输入法菜单里也可以打开「Paretly 设置…」。设置窗口里有「重新部署」。
用户配置在 ~/Library/Rime，设置写在 paretly.custom.yaml。

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
