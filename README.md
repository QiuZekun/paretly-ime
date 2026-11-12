# Paretly

Paretly 是 macOS 上的开源输入法，基于 [Rime / 中州韵](https://rime.im)。它是 [Squirrel / 鼠须管](https://github.com/rime/squirrel)（稳定版 1.1.2）的修改版，默认带上 [雾凇拼音 / Rime ICE](https://github.com/iDvel/rime-ice)，装好就能打字，不用自己找方案、改配置。

系统要求 macOS 13 或更新版本。本程序以 **GPL-3.0** 发布，全文在 `LICENSE.txt`。这是修改过的鼠须管，修改说明在 `NOTICE`，第三方组件和许可证原文在 `THIRD-PARTY-NOTICES.md`。

这个 App **没有公证**。公证需要付费的 Apple Developer 账号，Paretly 没有做这一步，安装包也没有签名。从网上载下来的磁盘镜像会被 Gatekeeper 拦截，按下面的步骤才能打开。

## 截图

截图待补。这里会放候选栏和「Paretly 设置…」窗口。

## 安装

到 GitHub Release 下载磁盘镜像：<https://github.com/QiuZekun/paretly-ime/releases>

1. 下载 `Paretly-unsigned.dmg`。第一个版本的标签是 `v0.1.0`。
2. 打开磁盘镜像，双击里面的 `Paretly.pkg`。
3. 安装位置是 `/Library/Input Methods/Paretly.app`。安装包会注册并尝试启用输入法，完成后可能会要求注销再登录。
4. 启动台里会有 **Paretly**。点它打开设置窗口。输入法本体仍在「输入法」目录里，启动台不显示那个目录。

也可以把 `Paretly.app` 放到 `~/Library/Input Methods/`，然后执行：

```sh
"$HOME/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --register-input-source
"$HOME/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --enable-input-source
```

## 未签名、未公证时怎么打开

安装包没有签名，也没有公证，所以第一次打开会被拦截。

到 **系统设置 > 隐私与安全性**，找到被拦截的 Paretly，点 **仍要打开**（Open Anyway）。

也可以先去掉隔离属性。把路径换成你下载的文件：

```sh
xattr -dr com.apple.quarantine ~/Downloads/Paretly-unsigned.dmg
```

磁盘镜像里的 `Paretly.pkg` 如果还是打不开，对它再执行一次同一条命令（镜像挂载后一般在 `/Volumes/Paretly/Paretly.pkg`）。

也可以在 `Paretly.pkg` 上按住 Control 点按（或右键），选 **打开**，再确认打开。

## 添加输入法

安装程序会尝试启用并选中 Paretly。如果菜单栏里还没有：

1. 打开 **系统设置 > 键盘 > 输入法**（Input Sources）。
2. 点添加，在简体中文或繁体中文下面选择 **Paretly**。
3. 菜单栏输入法图标换成 Paretly 后即可输入。

第一次部署会选用雾凇拼音，方案 id 是 `rime_ice`。切换方案用 Control+` 或 F4。

## 打开设置

菜单栏点 Paretly 的输入法图标，选 **Paretly 设置…**。系统语言是英文时这一项显示 **Settings…**，繁体中文显示 **Paretly 設定…**。启动台里的 **Paretly** 打开的是同一个窗口。窗口右上角的 **重新部署** 不改配色，只重新部署。

可以给浅色和深色各选一套配色，并改横排或竖排、候选字号、序号字号和圆角。配色卡片来自随包 `paretly.yaml` 的 `preset_color_schemes`，再叠上 `~/Library/Rime/paretly.yaml` 里的同名覆盖。

**应用** 只把这次改过的键写进 `~/Library/Rime/paretly.custom.yaml` 的 `patch:`，文件里原有的其它补丁会保留。这个文件如果已经存在，第一次覆盖前会复制成 `paretly.custom.yaml.bak`。写完后 Paretly 在进程内重新部署。

深色默认是「简约黑」（`clean_black`）。浅色默认仍是 `native`。

重新部署也可以在终端执行：

```sh
"/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --reload
```

## 用户配置

用户词库和配置在 `~/Library/Rime`。这是 Rime 各前端共用的目录。

Paretly 自己的前端设置写在：

- `~/Library/Rime/paretly.custom.yaml`（设置窗口点「应用」之后写在这里）
- `~/Library/Rime/paretly.yaml`（可选，用来覆盖随包的 `preset_color_schemes` 等同名键）

## 卸载

1. 先在菜单栏换成别的输入法。
2. 打开 **系统设置 > 键盘 > 输入法**，选中 Paretly，点减号删掉。
3. 删除程序。用安装包装的：

```sh
sudo rm -rf "/Library/Input Methods/Paretly.app" "/Applications/Paretly.app"
```

自己拷到用户目录的，删除 `~/Library/Input Methods/Paretly.app`。启动台里的 Paretly 也要删：`sudo rm -rf "/Applications/Paretly.app"`。

4. 可选：忘掉安装包记录。

```sh
sudo pkgutil --forget com.qiuzekun.inputmethod.Paretly
```

5. `~/Library/Rime` 是各 Rime 前端共用的。只卸 Paretly 时，可以删 `paretly.custom.yaml`、`paretly.custom.yaml.bak` 和用户目录里的 `paretly.yaml`。词库和其它方案留着，别的 Rime 输入法还要用。
6. 输入法菜单里如果还看得到 Paretly，注销再登录。

## 从源码构建

依赖和鼠须管相同：Xcode，以及 `action-install.sh` 下载的 librime 预编译包（librime 1.16.0，提交 `a251145`）和 Sparkle。librime 源码仍以 git 子模块记录在 `librime/`。

```sh
git clone --recursive https://github.com/QiuZekun/paretly-ime.git
cd paretly-ime
make package          # 生成未签名的 package/Paretly.pkg
make dmg              # 再包成 dist/Paretly-unsigned.dmg
```

`make` 会按 `versions/rime-ice.env` 下载雾凇拼音，放进 `data/rime-ice/`（这个目录不入库），编完再拷进 App 的 `Contents/SharedSupport`，并覆盖 `default.yaml`，让 `schema_list` 的第一项是 `rime_ice`。

本地想指定和某个标签一样的版本号时，设置 `MARKETING_VERSION`（不要带 `v`）。它会写入 `CFBundleShortVersionString` 和 `CFBundleVersion`，安装包版本也用这个值：

```sh
MARKETING_VERSION=0.1.0 make dmg
```

不设置时，Xcode 工程里的版本是 `0.1.0`。

更新雾凇拼音：改 `versions/rime-ice.env` 里的 tag 和完整 commit，然后运行：

```sh
bash tools/update-rime-ice.sh
```

### 图标

菜单栏图标和 App 图标从 `resources/icons/src/` 的 SVG 生成。现在是占位图：菜单栏是圆角方框里的黑色粗体 P，App 图标是圆角方块上的白色粗体 P。换正式图时，替换 SVG，运行下面的脚本，把生成的文件一起提交：

```sh
python3 resources/icons/generate.py
```

脚本只用 Python 3 标准库，会重写：

- `resources/paretly.tiff`：16 pt 的 @1x（16×16，72 dpi）和 @2x（32×32，144 dpi）。`Info.plist` 里 `TISIconIsTemplate` 为真，`tsInputMethodIconFileKey` 和每个输入模式的 `tsInputModeMenuIconFileKey`（以及备用、面板图标）都指向这个文件。系统会按模板图给浅色和深色菜单栏重新着色。
- `resources/paretly.pdf`：同一张图的 16×16 pt 矢量，角色和鼠须管的 `rime.pdf` 一样，打进 App 里。
- `resources/AppIcon.icns`，以及 `Assets.xcassets/AppIcon.appiconset/` 的全套尺寸。`CFBundleIconFile` 是 `AppIcon.icns`。

### 启动台

输入法在 `/Library/Input Methods`，`LSUIElement` 为真，启动台不会列出它。`make` 编译 `launcher/main.swift`，放进 `Paretly.app/Contents/Resources/ParetlyLauncher.tar`。`scripts/postinstall` 再解到 `/Applications/Paretly.app`。

这是一个普通前台 App，图标和输入法相同，名字也是 Paretly。点开后如果输入法已在运行，就通知它打开现有的设置窗口；没在运行就先把输入法拉起来再打开。设置窗口里的「重新部署」调用原来的 `deploy()`。

不用指向输入法的替身。替身的目标不在启动台扫描的目录里，而且打开 `LSUIElement` 的输入法不会出现设置窗口。安装包里也不把第二个 `.app` 嵌进输入法目录，避免 `pkgbuild` 把它当成另一个可重定位的 bundle。

## 发布

在要发布的提交上推送标签 `v*`。标签必须是 `v` 加上由点分开的两到四段数字，例如 `v0.1.0`。`v0.1.0-rc1` 这种不会通过版本检查。

GitHub Actions 会沿用原来的 macOS 任务打未签名的 `Paretly-unsigned.dmg`。构建前把标签去掉前缀 `v`，设成 `CFBundleShortVersionString`（同时写入 `CFBundleVersion` 和 pkg 版本）。然后用 `GITHUB_TOKEN`（`contents: write`）建一个 GitHub Release，附上这个 dmg，说明由 GitHub 自动生成。

第一个发布用的标签是 `v0.1.0`，对应 `CHANGELOG.md` 里的同名条目。推送这个标签才会真正发出 Release。不要用 `package/bump_version`：那是鼠须管留下的本地脚本，会自己提交并打标签。

`main` 和 pull request 上的构建不发布，版本号保持工程里的 `0.1.0`。

## 许可与致谢

Paretly 以 **GNU GPL-3.0** 发布，见 `LICENSE.txt`。`NOTICE` 说明它修改自鼠须管 1.1.2，并保留上游版权声明。雾凇拼音是 **GPL-3.0 only**。

| 项目 | 说明 | 许可 |
| --- | --- | --- |
| [Rime / 中州韵](https://rime.im) | 输入法引擎 | 见各组件 |
| [librime](https://github.com/rime/librime) | 引擎库。子模块，构建时用鼠须管同一份 macOS 预编译包 | BSD 3-Clause |
| [Squirrel / 鼠须管](https://github.com/rime/squirrel) | macOS 前端。基线 tag `1.1.2`（`876adebaf2f612951dcdca8a591de65401222b9a`）。作者见 `THIRD-PARTY-NOTICES.md` | GPL-3.0 |
| [Rime ICE / 雾凇拼音](https://github.com/iDvel/rime-ice) | 随包默认方案，作者 Dvel。固定 `2026.06.30`（`6810e8916d160498620a16fef2135956fecbd485`） | GPL-3.0 only |
| [librime-lua](https://github.com/hchunhui/librime-lua)、[Lua](https://www.lua.org) | 方案脚本。Lua 5.4.8 | BSD 3-Clause、MIT |
| [librime-octagram](https://github.com/lotem/librime-octagram) | 插件 | GPL-3.0 |
| [librime-predict](https://github.com/rime/librime-predict) | 插件 | BSD 3-Clause |
| [plum / 东风破](https://github.com/rime/plum) | 配方安装 | LGPL-3.0 |
| [OpenCC](https://github.com/BYVoid/OpenCC) | 简繁转换，作者 Carbo Kuo | Apache-2.0 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 更新框架（自动更新未开启） | MIT |
| Boost、glog、LevelDB、marisa-trie、yaml-cpp、darts-clone、UTF8-CPP | librime / OpenCC 链接的库 | 见 `THIRD-PARTY-NOTICES.md` |

每份需要随二进制保留的许可证原文在 `licenses/`，对照表在 `THIRD-PARTY-NOTICES.md`。

## English

Paretly is an open-source macOS input method built on [Rime](https://rime.im). It is a modified version of [Squirrel / 鼠须管](https://github.com/rime/squirrel) 1.1.2 and ships with [Rime ICE](https://github.com/iDvel/rime-ice) (雾凇拼音) already selected, so a new install can type without writing a config by hand.

macOS 13 or later. Paretly is **GPL-3.0**. The license is `LICENSE.txt`. `NOTICE` records the changes from Squirrel. Bundled components and their license texts are in `THIRD-PARTY-NOTICES.md`.

The app is **not notarized**. Notarization requires a paid Apple Developer account, and Paretly does not have one. The disk image is also unsigned, so Gatekeeper blocks a download until you use the steps below.

### Screenshots

Screenshots are not in the tree yet. This section will show the candidate window and the Paretly settings window.

### Install

Download the disk image from the GitHub Releases page: <https://github.com/QiuZekun/paretly-ime/releases>

1. Download `Paretly-unsigned.dmg`. The first release tag is `v0.1.0`.
2. Open the disk image and run `Paretly.pkg`.
3. The package installs to `/Library/Input Methods/Paretly.app`. It registers the input source and tries to enable it. You may need to log out and back in.
4. Launchpad gains a **Paretly** app. Open it to show the settings window. The input method itself stays in Input Methods, which Launchpad does not list.

A copy in `~/Library/Input Methods/` also works. Run `Paretly --register-input-source` and `--enable-input-source` from that bundle.

### Open an unsigned, unnotarized download

The package is unsigned and not notarized, so macOS blocks it the first time.

Open **System Settings > Privacy & Security** and choose **Open Anyway** (仍要打开) for Paretly.

Or clear the quarantine attribute. Use the path of the file you downloaded:

```sh
xattr -dr com.apple.quarantine ~/Downloads/Paretly-unsigned.dmg
```

If `Paretly.pkg` inside the image is still blocked, run the same command on it (after mounting, that is usually `/Volumes/Paretly/Paretly.pkg`).

You can also Control-click `Paretly.pkg` and choose **Open**.

### Add the input source

The installer tries to enable Paretly. If it is missing from the menu bar:

1. Open **System Settings > Keyboard > Input Sources**.
2. Add **Paretly** under Simplified Chinese or Traditional Chinese.
3. Select it from the input menu.

The first deploy selects schema `rime_ice`. Switch schemas with Control+` or F4.

### Open settings

From the input menu, choose **Paretly 设置…**. The English title is **Settings…**. Traditional Chinese shows **Paretly 設定…**. The **Paretly** app in Launchpad opens the same window. **Deploy** in that window redeploys without writing theme changes.

Pick a light scheme and a dark scheme, then set horizontal or vertical candidates, candidate size, label size, and corner radius. Cards come from `preset_color_schemes` in the bundled `paretly.yaml`, with the same keys from `~/Library/Rime/paretly.yaml` overlaid.

**Apply** writes only the keys you changed into `~/Library/Rime/paretly.custom.yaml` under `patch:`. Other patches in that file stay. The first time Apply overwrites an existing file, it is copied to `paretly.custom.yaml.bak`. Paretly then redeploys in-process.

Dark mode defaults to **简约黑 / Clean Black** (`clean_black`). Light mode stays on `native`.

Reload from the terminal:

```sh
"/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --reload
```

### User config

User data lives in `~/Library/Rime`, the directory shared by Rime front ends.

Paretly's own frontend files are:

- `~/Library/Rime/paretly.custom.yaml`, written when you choose Apply in settings
- `~/Library/Rime/paretly.yaml`, optional overrides such as `preset_color_schemes`

### Uninstall

1. Switch the menu bar to another input source.
2. Open **System Settings > Keyboard > Input Sources**, select Paretly, and remove it.
3. Delete the app. For the package install:

```sh
sudo rm -rf "/Library/Input Methods/Paretly.app" "/Applications/Paretly.app"
```

If you copied the input method yourself, delete `~/Library/Input Methods/Paretly.app` as well. Also remove the Launchpad app with `sudo rm -rf "/Applications/Paretly.app"` if it is still there.

4. Optionally forget the package receipt:

```sh
sudo pkgutil --forget com.qiuzekun.inputmethod.Paretly
```

5. `~/Library/Rime` is shared with other Rime apps. To remove only Paretly's frontend settings, delete `paretly.custom.yaml`, `paretly.custom.yaml.bak`, and a user `paretly.yaml`. Leave dictionaries and other schemas in place.
6. Log out and back in if Paretly is still listed.

### Build

Same dependencies as Squirrel. `action-install.sh` downloads the prebuilt librime 1.16.0 (`a251145`) that Squirrel's CI uses, plus Sparkle. The librime sources stay as a git submodule.

```sh
make package    # unsigned package/Paretly.pkg
make dmg        # dist/Paretly-unsigned.dmg
```

`versions/rime-ice.env` pins rime-ice. `bash tools/update-rime-ice.sh` refreshes `data/rime-ice/` after you change the pin. The build copies that tree into SharedSupport and keeps `rime_ice` as the first entry in `default.yaml`.

Set `MARKETING_VERSION` without the leading `v` to match a tag. It becomes `CFBundleShortVersionString`, `CFBundleVersion`, and the package version:

```sh
MARKETING_VERSION=0.1.0 make dmg
```

Without it, the Xcode project version `0.1.0` is used.

### Icons

Menu-bar and app icons are generated from the SVGs in `resources/icons/src/`. The current art is a placeholder: a black bold P inside a rounded-square outline for the menu bar, and a white bold P on a rounded square for the app icon. Replace the SVGs, rerun the script, and commit the generated files:

```sh
python3 resources/icons/generate.py
```

The script uses only the Python 3 standard library. It rewrites:

- `resources/paretly.tiff` — a 16 pt template with @1x (16×16 at 72 dpi) and @2x (32×32 at 144 dpi). `TISIconIsTemplate` is true, and `tsInputMethodIconFileKey` plus each mode's `tsInputModeMenuIconFileKey` (and the alternate and palette keys) name this file. macOS tints the template for light and dark menu bars.
- `resources/paretly.pdf` — the same drawing as a 16×16 pt vector, the role `rime.pdf` has in Squirrel. It is copied into the app.
- `resources/AppIcon.icns` and every size in `Assets.xcassets/AppIcon.appiconset/`. `CFBundleIconFile` is `AppIcon.icns`.

### Launchpad

The input method lives in `/Library/Input Methods` with `LSUIElement` set, so Launchpad does not list it. `make` compiles `launcher/main.swift` into `Paretly.app/Contents/Resources/ParetlyLauncher.tar`. `scripts/postinstall` unpacks that to `/Applications/Paretly.app`.

That app is a normal foreground bundle with the same icon and the name Paretly. If the input method is already running, the launcher asks it to open the existing settings window. If it is not running, the launcher starts it and that process opens settings. **Deploy** in the settings window calls the existing `deploy()`.

An alias to the input method would not show up in Launchpad: the target is outside the folders Launchpad scans, and opening the `LSUIElement` bundle does not present settings. The package also does not nest a second `.app` inside the input method, because `pkgbuild` would treat that as another relocatable bundle.

### Release

Push a `v*` tag on the commit you want to ship. The tag must be `v` plus two to four numeric components, such as `v0.1.0`. A tag like `v0.1.0-rc1` fails the version check.

GitHub Actions reuses the existing macOS job to build `Paretly-unsigned.dmg`. Before the build it strips the leading `v` and sets `CFBundleShortVersionString` (and `CFBundleVersion`, and the package version) from that number. It then publishes a GitHub Release with `GITHUB_TOKEN` (`contents: write`), attaches the dmg, and uses GitHub's auto-generated notes.

The tag for the first release is `v0.1.0`, the entry at the top of `CHANGELOG.md`. Pushing that tag is what creates the Release. Do not use `package/bump_version`; that leftover Squirrel script commits and creates a tag locally.

Pushes to `main` and pull requests only build the disk image. They keep the project version `0.1.0` and do not publish a Release.

### Credits and licenses

Paretly is **GPL-3.0**. See `LICENSE.txt` and `NOTICE`. Rime ICE is **GPL-3.0 only**.

- [Rime](https://rime.im)
- [librime](https://github.com/rime/librime) — BSD 3-Clause. Submodule, plus the prebuilt macOS archive Squirrel documents.
- [Squirrel / 鼠须管](https://github.com/rime/squirrel) — GPL-3.0. Base tag `1.1.2`, commit `876adebaf2f612951dcdca8a591de65401222b9a`. Authors are listed in `THIRD-PARTY-NOTICES.md`.
- [Rime ICE / 雾凇拼音](https://github.com/iDvel/rime-ice) — GPL-3.0 only, by Dvel. Pinned tag `2026.06.30`, commit `6810e8916d160498620a16fef2135956fecbd485`.
- [librime-lua](https://github.com/hchunhui/librime-lua) and [Lua 5.4.8](https://www.lua.org) — BSD 3-Clause and MIT.
- [librime-octagram](https://github.com/lotem/librime-octagram) — GPL-3.0.
- [librime-predict](https://github.com/rime/librime-predict) — BSD 3-Clause.
- [plum](https://github.com/rime/plum) — LGPL-3.0.
- [OpenCC](https://github.com/BYVoid/OpenCC) — Apache-2.0, by Carbo Kuo.
- [Sparkle](https://github.com/sparkle-project/Sparkle) — MIT. Automatic updates stay off.
- Boost, glog, LevelDB, marisa-trie, yaml-cpp, darts-clone, and UTF8-CPP — licenses in `THIRD-PARTY-NOTICES.md`.

Verbatim license texts that binary distribution has to keep are in `licenses/`.
