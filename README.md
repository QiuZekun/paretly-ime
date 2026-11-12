# Paretly

开源、开箱即用的 macOS 输入法。基于 Rime，默认带上雾凇拼音，装好就能打字，不用自己找方案、改配置。

当前是第一阶段：能编译、能安装、能用的未签名安装包。设置窗口和新的深色主题还没做，正式发布（签名、公证）也还没做。

## 安装

系统要求 macOS 13 或更新版本。

1. 从 GitHub Actions 的构建产物下载 `Paretly-unsigned.dmg`（仓库还没有 Release）。
2. 打开磁盘镜像，双击里面的 `Paretly.pkg`。
3. 安装位置是 `/Library/Input Methods/Paretly.app`，和鼠须管一样装到系统输入法目录。安装包会注册并尝试启用输入法，完成后可能会要求注销再登录。
4. 也可以把 `Paretly.app` 放到 `~/Library/Input Methods/`，然后执行：

```sh
"$HOME/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --register-input-source
"$HOME/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --enable-input-source
```

安装包本身没有签名。下载下来的 pkg 第一次打开时，macOS 会拦截。

## 未签名时怎么打开

到 **系统设置 > 隐私与安全性**，找到被拦截的 Paretly，点 **仍要打开**（Open Anyway）。

也可以在 `Paretly.pkg` 上按住 Control 点按（或右键），选 **打开**，再确认打开。

签名和公证需要付费的 Apple Developer 账号，这一步还没做。没有公证时，从网络下载的安装包都会走上面的 Gatekeeper 确认。

## 添加输入法

安装程序会尝试启用并选中 Paretly。如果菜单栏里还没有：

1. 打开 **系统设置 > 键盘 > 输入法**（Input Sources）。
2. 点添加，在简体中文或繁体中文下面选择 **Paretly**。
3. 菜单栏输入法图标换成 Paretly 后即可输入。

第一次部署会选用雾凇拼音，方案 id 是 `rime_ice`。切换方案用 Control+` 或 F4。

用户词库和配置在 `~/Library/Rime`，这是 Rime 各前端共用的目录。前端外观配置文件是 `paretly.yaml`。

重新部署（原来的 `--reload`，可执行文件名是 Paretly）：

```sh
"/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --reload
```

## 从源码构建

依赖和鼠须管相同：Xcode、以及 `action-install.sh` 下载的 librime 预编译包（librime 1.16.0，提交 `a251145`）和 Sparkle。librime 源码仍以 git 子模块记录在 `librime/`。

```sh
git clone --recursive https://github.com/QiuZekun/paretly-ime.git
cd paretly-ime
make package          # 生成未签名的 package/Paretly.pkg
make dmg              # 再包成 dist/Paretly-unsigned.dmg
```

`make` 会按 `versions/rime-ice.env` 下载雾凇拼音，放进 `data/rime-ice/`（这个目录不入库），编完再拷进 App 的 `Contents/SharedSupport`，并覆盖 `default.yaml`，让 `schema_list` 的第一项是 `rime_ice`。

更新雾凇拼音：改 `versions/rime-ice.env` 里的 tag 和完整 commit，然后运行：

```sh
bash tools/update-rime-ice.sh
```

## 许可与致谢

Paretly 以 **GNU GPL-3.0** 发布，见仓库里的 `LICENSE.txt`。上游源文件里的版权声明都保留着。

本项目站在这些项目上面：

| 项目 | 说明 | 许可 |
| --- | --- | --- |
| [Rime / 中州韵](https://rime.im) | 输入法引擎 | 见各组件 |
| [librime](https://github.com/rime/librime) | 引擎库。本仓库的子模块，构建时按鼠须管的方式使用其 macOS 预编译包 | BSD 3-Clause |
| [Squirrel / 鼠须管](https://github.com/rime/squirrel) | macOS 前端。Paretly 基于稳定版 tag `1.1.2`（`876adebaf2f612951dcdca8a591de65401222b9a`） | GPL-3.0 |
| [Rime ICE / 雾凇拼音](https://github.com/iDvel/rime-ice) | 随包默认方案。当前固定 `2026.06.30`（`6810e8916d160498620a16fef2135956fecbd485`） | GPL-3.0 |
| [plum / 东风破](https://github.com/rime/plum) | 配方安装 | LGPL-3.0 |
| [OpenCC](https://github.com/BYVoid/OpenCC) | 简繁转换数据 | Apache-2.0 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 更新框架（自动更新尚未配置） | MIT |

鼠须管还引用了 Boost、LevelDB、yaml-cpp、marisa、glog 等库，版权说明见上游 README 的历史记录和各库自己的许可证。

雾凇拼音的词典、Lua 脚本和 OpenCC 补充数据随安装包放在 SharedSupport 里。更新方案时请继续遵守 GPL-3.0，并保留 rime-ice 的版权声明。

## English

Paretly is an open-source macOS input method built on Rime. It ships with [Rime ICE](https://github.com/iDvel/rime-ice) (雾凇拼音) already selected, so a new install can type without writing a config by hand.

This is phase 1: an unsigned installer. A native settings window and a new dark theme are later work. Signing and notarization need a paid Apple Developer account and are not done yet.

### Install

macOS 13 or later.

1. Download `Paretly-unsigned.dmg` from the GitHub Actions artifacts. There is no GitHub Release yet.
2. Open the disk image and run `Paretly.pkg`.
3. The package installs to `/Library/Input Methods/Paretly.app`, the same location Squirrel uses. It registers the input source and tries to enable it. You may need to log out and back in.
4. A copy in `~/Library/Input Methods/` also works. Run `Paretly --register-input-source` and `--enable-input-source` from that bundle.

The package is unsigned. If Gatekeeper blocks it, open **System Settings > Privacy & Security** and choose **Open Anyway**, or Control-click `Paretly.pkg` and choose **Open**.

### Add the input source

The installer tries to enable Paretly. If it is missing from the menu bar:

1. Open **System Settings > Keyboard > Input Sources**.
2. Add **Paretly** under Simplified Chinese or Traditional Chinese.
3. Select it from the input menu.

The first deploy selects schema `rime_ice`. Switch schemas with Control+` or F4. User data lives in `~/Library/Rime`. Frontend settings are `paretly.yaml`.

Reload / redeploy:

```sh
"/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --reload
```

### Build

Same dependencies as Squirrel. `action-install.sh` downloads the prebuilt librime 1.16.0 (`a251145`) that Squirrel's CI uses. The librime sources stay as a git submodule.

```sh
make package    # unsigned package/Paretly.pkg
make dmg        # dist/Paretly-unsigned.dmg
```

`versions/rime-ice.env` pins rime-ice. `bash tools/update-rime-ice.sh` refreshes `data/rime-ice/` after you change the pin. The build copies that tree into SharedSupport and keeps `rime_ice` as the first entry in `default.yaml`.

### Credits and licenses

Paretly is **GPL-3.0**. See `LICENSE.txt`. Upstream copyright notices stay in the source files.

- [Rime](https://rime.im)
- [librime](https://github.com/rime/librime) — BSD 3-Clause. Submodule, plus the prebuilt macOS archive Squirrel documents.
- [Squirrel / 鼠须管](https://github.com/rime/squirrel) — GPL-3.0. Base tag `1.1.2`, commit `876adebaf2f612951dcdca8a591de65401222b9a`.
- [Rime ICE / 雾凇拼音](https://github.com/iDvel/rime-ice) — GPL-3.0. Pinned tag `2026.06.30`, commit `6810e8916d160498620a16fef2135956fecbd485`.
- [plum](https://github.com/rime/plum) — LGPL-3.0.
- [OpenCC](https://github.com/BYVoid/OpenCC) — Apache-2.0.
- [Sparkle](https://github.com/sparkle-project/Sparkle) — MIT. Automatic updates are turned off until Paretly has its own signed feed.

Squirrel also vendors Boost, LevelDB, yaml-cpp, marisa, glog, and other libraries under their own licenses. Those notices are unchanged.
