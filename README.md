# Paretly

Paretly 是 macOS 上的开源输入法，基于 [Rime / 中州韵](https://rime.im)。它是 [Squirrel / 鼠须管](https://github.com/rime/squirrel)（稳定版 1.1.2）的修改版，默认带上 [雾凇拼音 / Rime ICE](https://github.com/iDvel/rime-ice)，装好就能打字，不用自己找方案、改配置。

系统要求 macOS 13 或更新版本。本程序以 **GPL-3.0** 发布，全文在 `LICENSE.txt`。这是修改过的鼠须管，修改说明在 `NOTICE`，第三方组件和许可证原文在 `THIRD-PARTY-NOTICES.md`。

这个 App **没有公证**。公证需要付费的 Apple Developer 账号，Paretly 没有做这一步，安装包也没有签名。从网上载下来的安装包会被 Gatekeeper 拦截，按下面的步骤才能打开。

## 截图

截图待补。这里会放候选栏和「Paretly 设置…」窗口。

## 安装

到 GitHub Release 下载安装包：<https://github.com/QiuZekun/paretly-ime/releases>

1. 下载 `Paretly-unsigned.pkg`。第一个版本的标签是 `v0.1.0`。
2. 双击这个安装包。
3. 安装位置是 `/Library/Input Methods/Paretly.app`。再装一次会原地替换输入法和 `/Applications` 里的 Paretly。安装脚本会结束正在运行的 Paretly，重新注册并启用输入法，然后重新打开，一般不用注销。如果菜单栏里还没有，注销再登录，或在 **系统设置 > 键盘 > 输入法** 里添加 Paretly。
4. 启动台里会有 **Paretly**。点它打开设置窗口。输入法本体仍在「输入法」目录里，启动台不显示那个目录。

也可以把 `Paretly.app` 放到 `~/Library/Input Methods/`，然后执行：

```sh
"$HOME/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --register-input-source
"$HOME/Library/Input Methods/Paretly.app/Contents/MacOS/Paretly" --enable-input-source
```

## 未签名、未公证时怎么打开

安装包没有签名，也没有公证，所以第一次打开会被拦截。

在 `Paretly-unsigned.pkg` 上右键（或按住 Control 点按），选择 **打开**，再确认打开。

也可以到 **系统设置 > 隐私与安全性**，找到被拦截的安装包，点 **仍要打开**（Open Anyway）。

也可以先去掉隔离属性。把路径换成你下载的文件：

```sh
xattr -dr com.apple.quarantine ~/Downloads/Paretly-unsigned.pkg
```

## 添加输入法

安装程序会尝试启用并选中 Paretly。如果菜单栏里还没有：

1. 打开 **系统设置 > 键盘 > 输入法**（Input Sources）。
2. 点添加，在简体中文或繁体中文下面选择 **Paretly**。
3. 菜单栏输入法图标换成 Paretly 后即可输入。

第一次部署会选用雾凇拼音，方案 id 是 `rime_ice`。切换方案用 Control+` 或 F4。

## 打开设置

菜单栏点 Paretly 的输入法图标，选 **设置…**。英文界面这一项是 **Settings…**，繁体中文是 **設定…**。启动台里的 **Paretly** 打开同一个窗口。窗口会记住大小和位置。Command-W 或 Esc 关闭窗口。

工具栏分成五页：

- **常规**：设置文件的位置，以及当前浅色、深色配色。
- **外观**：浅色和深色配色、候选窗预览、配色卡片和圆角。
- **输入**：横排或竖排、候选字号、序号字号。
- **更新**：自动检查更新、**接收测试版（Beta）**，以及 **检查更新…**。有新版本时 **一键更新** 会要求管理员密码并原地安装；失败则打开安装器。
- **关于**：图标、版本、GPL-3.0，以及 Squirrel、librime、雾凇拼音和本仓库的链接。

窗口底部的 **重新部署** 不改这些选择，只重新部署。**应用** 写入并重新部署。

可以给浅色和深色各选一套配色。配色卡片来自随包 `paretly.yaml` 的 `preset_color_schemes`，再叠上 `~/Library/Rime/paretly.yaml` 里的同名覆盖。点卡片会填入当前选中的外观。

**应用** 只把这次改过的键写进 `~/Library/Rime/paretly.custom.yaml` 的 `patch:`，文件里原有的其它补丁会保留。这个文件如果已经存在，第一次覆盖前会复制成 `paretly.custom.yaml.bak`。写完后 Paretly 在进程内重新部署。

深色默认是「简约黑」（`clean_black`）。浅色默认仍是 `native`。

输入法菜单里的 **关于 Paretly** 会打开关于面板，内容和「关于」页相同。

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
```

`make` 会按 `versions/rime-ice.env` 下载雾凇拼音，放进 `data/rime-ice/`（这个目录不入库），编完再拷进 App 的 `Contents/SharedSupport`，并覆盖 `default.yaml`，让 `schema_list` 的第一项是 `rime_ice`。

本地想指定和某个标签一样的营销版本时，设置 `MARKETING_VERSION`（不要带 `v`）。它会写入 `CFBundleShortVersionString`。没有另外设置 `CURRENT_PROJECT_VERSION` 时，`CFBundleVersion` 和安装包版本也用这个值：

```sh
MARKETING_VERSION=0.1.0 make package
```

不设置时，Xcode 工程里的版本是 `0.1.0`。

更新雾凇拼音：改 `versions/rime-ice.env` 里的 tag 和完整 commit，然后运行：

```sh
bash tools/update-rime-ice.sh
```

### 图标

菜单栏图标和 App 图标从 `resources/icons/src/` 的 SVG 生成。菜单栏是一枚黑色粗体 P，右边一条细的文字光标，没有外框（模板图，浅色和深色菜单栏由系统着色）。App 图标是 macOS 圆角方块，纵向渐变 `#262830` 到 `#0A0A0C`，白色粗体 P，下面一条圆角蓝条 `#5A96FF`，带轻微投影。换图时替换 SVG，运行下面的脚本，把生成的文件一起提交：

```sh
python3 resources/icons/generate.py
```

脚本只用 Python 3 标准库，会重写：

- `resources/paretly.tiff`：16 pt 和 18 pt 的 @1x / @2x（16×16@72 dpi、32×32@144 dpi、18×18@72 dpi、36×36@144 dpi）。`Info.plist` 里 `TISIconIsTemplate` 为真，`tsInputMethodIconFileKey` 和每个输入模式的 `tsInputModeMenuIconFileKey`（以及备用、面板图标）都指向这个文件。系统会按模板图给浅色和深色菜单栏重新着色。
- `resources/paretly.pdf`：同一张图的 18×18 pt 矢量，角色和鼠须管的 `rime.pdf` 一样，打进 App 里。
- `resources/AppIcon.icns` 带上 macOS 要的全部尺寸（16、32、64、128、256、512、1024，含 @2x 对应的类型），`Assets.xcassets/AppIcon.appiconset/` 是同一套图。`CFBundleIconFile` 是 `AppIcon.icns`。输入法和 `/Applications` 里的启动台 App 都用这个文件。

### 启动台

输入法在 `/Library/Input Methods`，`LSUIElement` 为真，启动台不会列出它。`make` 编译 `launcher/main.swift`，放进 `Paretly.app/Contents/Resources/ParetlyLauncher.tar`。`scripts/postinstall` 再解到 `/Applications/Paretly.app`。

这是一个普通前台 App，图标和输入法相同，名字也是 Paretly。点开后如果输入法已在运行，就通知它打开现有的设置窗口；没在运行就先把输入法拉起来再打开。设置窗口里的「重新部署」调用原来的 `deploy()`。

不用指向输入法的替身。替身的目标不在启动台扫描的目录里，而且打开 `LSUIElement` 的输入法不会出现设置窗口。安装包里也不把第二个 `.app` 嵌进输入法目录，避免 `pkgbuild` 把它当成另一个可重定位的 bundle。

## 发布

在要发布的提交上推送标签 `v*`。标签必须是 `v` 加上由点分开的两到四段数字，例如 `v0.1.0`。`v0.1.0-rc1` 这种不会通过版本检查。

GitHub Actions 会在原来的 macOS 任务里打未签名的 `package/Paretly.pkg`，再拷成 `dist/Paretly-unsigned.pkg`。每次构建把 `CFBundleVersion` 和安装包版本设成 `github.run_number`，这样新的 pkg 会盖过已经装上的那一份。推送标签时，再把标签去掉前缀 `v`，设成 `CFBundleShortVersionString`。然后用 `GITHUB_TOKEN`（`contents: write`）建一个 GitHub Release，附上这个 pkg 和 `Paretly-unsigned.pkg.sha256`（`sha256sum` 的结果），说明由 GitHub 自动生成。安装脚本会停掉正在运行的 Paretly，注册输入法，并把启动台用的 Paretly 解到 `/Applications`。

第一个发布用的标签是 `v0.1.0`，对应 `CHANGELOG.md` 里的同名条目。推送这个标签才会真正发出 Release。不要用 `package/bump_version`：那是鼠须管留下的本地脚本，会自己提交并打标签。

pull request 上的构建不发布，营销版本保持工程里的 `0.1.0`，`CFBundleVersion` 仍是当次的 `github.run_number`。构件名是 `Paretly-unsigned.pkg`。

推送到 `main` 并且安装包构建成功之后，会另外发一个 **预发布**（prerelease）。它不会标成 Latest，也不会打 `v*` 标签。标签是 `beta-<运行号>`，标题是 `<营销版本>-beta.<运行号>`，例如 `0.1.0-beta.42`。附件同样是 `Paretly-unsigned.pkg` 和 `.sha256`。只保留最近 5 个测试版，更早的 `beta-*` 发布和标签会删掉。正式的 `v*` 发布流程不变。

## 检查更新

输入法菜单和设置窗口（启动台里的 Paretly 打开的就是这个窗口）都有 **检查更新…**。Paretly 读取 GitHub Releases 里 `QiuZekun/paretly-ime` 的最新正式版本（跳过草稿和预发布），用标签 `vX.Y.Z` 和本机的 `CFBundleShortVersionString` 比较。

有新版本时弹出说明，可以选择 **一键更新**、**以后再说** 或 **跳过此版本**。下载写到 `~/Downloads/Paretly-unsigned.pkg`，核对文件大小和 SHA-256，然后弹出系统密码框，用管理员权限原地安装，并重新打开输入法。如果这一步失败，就改用安装器打开安装包。安装包没有签名。如果系统拦截，在安装包上右键选择「打开」，或到隐私与安全性里点「仍要打开」。

设置里的 **接收测试版（Beta）** 默认关闭。`main` 上打出来的测试版构建默认打开。打开之后，检查更新会把预发布算进去，先比版本号，再比构建号。同一个 `0.1.0` 上，构建号更大的测试版比已发布的稳定版新；`0.2.0` 仍然比任何 `0.1.0-beta.N` 新。

已经是最新版本时会说明。仓库还没有正式 Release，或者 GitHub 对最新 Release 返回 404 时，手动检查显示「当前已是最新版本」，并写明目前还没有发布新版本和当前版本号；这不是错误。只有网络或 HTTP 失败才会报错，并带上原因。输入法菜单和设置窗口里的按钮都会触发同一次检查，提示会把输入法调到前台。输入法启动时最多每天自动检查一次，设置里的开关默认是开的。这里不用 Sparkle：未签名的安装包没法走 Sparkle 的 EdDSA 签名安装。

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

The app is **not notarized**. Notarization requires a paid Apple Developer account, and Paretly does not have one. The installer package is also unsigned, so Gatekeeper blocks a download until you use the steps below.

### Screenshots

Screenshots are not in the tree yet. This section will show the candidate window and the Paretly settings window.

### Install

Download the installer from the GitHub Releases page: <https://github.com/QiuZekun/paretly-ime/releases>

1. Download `Paretly-unsigned.pkg`. The first release tag is `v0.1.0`.
2. Double-click the package.
3. The package installs to `/Library/Input Methods/Paretly.app`. Installing it again replaces that bundle and the Paretly app in `/Applications`. The scripts stop the running input method, register and enable it again, and open it, so a logout is not required. If it is still missing from the menu bar, log out and back in, or add Paretly in **System Settings > Keyboard > Input Sources**.
4. Launchpad gains a **Paretly** app. Open it to show the settings window. The input method itself stays in Input Methods, which Launchpad does not list.

A copy in `~/Library/Input Methods/` also works. Run `Paretly --register-input-source` and `--enable-input-source` from that bundle.

### Open an unsigned, unnotarized download

The package is unsigned and not notarized, so macOS blocks it the first time.

Right-click `Paretly-unsigned.pkg` and choose **Open**, then confirm.

Or open **System Settings > Privacy & Security** and choose **Open Anyway** (仍要打开).

Or clear the quarantine attribute. Use the path of the file you downloaded:

```sh
xattr -dr com.apple.quarantine ~/Downloads/Paretly-unsigned.pkg
```

### Add the input source

The installer tries to enable Paretly. If it is missing from the menu bar:

1. Open **System Settings > Keyboard > Input Sources**.
2. Add **Paretly** under Simplified Chinese or Traditional Chinese.
3. Select it from the input menu.

The first deploy selects schema `rime_ice`. Switch schemas with Control+` or F4.

### Open settings

From the input menu, choose **Settings…**. Simplified Chinese shows **设置…**. Traditional Chinese shows **設定…**. The **Paretly** app in Launchpad opens the same window. The window remembers its size and position. Command-W or Esc closes it.

The toolbar has five tabs:

- **General**: where settings are saved, and the current light and dark schemes.
- **Appearance**: light and dark schemes, the candidate preview, scheme cards, and corner radius.
- **Input**: horizontal or vertical candidates, candidate size, and label size.
- **Updates**: automatic checks, **Receive beta updates**, and **Check for Updates…**. **Update Now** asks for an administrator password and installs in place; if that fails, the package opens in Installer.
- **About**: the icon, version, GPL-3.0, and links to Squirrel, librime, Rime ICE, and this repository.

**Deploy** at the bottom reloads Rime without changing these choices. **Apply** writes them and redeploys.

Pick a light scheme and a dark scheme. Cards come from `preset_color_schemes` in the bundled `paretly.yaml`, with the same keys from `~/Library/Rime/paretly.yaml` overlaid. A card fills the appearance selected above the grid.

**Apply** writes only the keys you changed into `~/Library/Rime/paretly.custom.yaml` under `patch:`. Other patches in that file stay. The first time Apply overwrites an existing file, it is copied to `paretly.custom.yaml.bak`. Paretly then redeploys in-process.

Dark mode defaults to **简约黑 / Clean Black** (`clean_black`). Light mode stays on `native`.

**About Paretly** in the input menu opens an About panel with the same credits as the About tab.

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
```

`versions/rime-ice.env` pins rime-ice. `bash tools/update-rime-ice.sh` refreshes `data/rime-ice/` after you change the pin. The build copies that tree into SharedSupport and keeps `rime_ice` as the first entry in `default.yaml`.

Set `MARKETING_VERSION` without the leading `v` to match a tag. It becomes `CFBundleShortVersionString`. When `CURRENT_PROJECT_VERSION` is unset, that same string is also `CFBundleVersion` and the package version:

```sh
MARKETING_VERSION=0.1.0 make package
```

Without it, the Xcode project version `0.1.0` is used.

### Icons

Menu-bar and app icons are generated from the SVGs in `resources/icons/src/`. The menu icon is a black bold P with a thin text cursor to its right and no box, so macOS can tint the template on light and dark menu bars. The app icon is a macOS rounded square with a vertical gradient from `#262830` to `#0A0A0C`, a white bold P, a short rounded `#5A96FF` bar under the P, and a soft shadow. Replace the SVGs, rerun the script, and commit the generated files:

```sh
python3 resources/icons/generate.py
```

The script uses only the Python 3 standard library. It rewrites:

- `resources/paretly.tiff` — 16 pt and 18 pt templates, each at @1x and @2x (16×16 at 72 dpi, 32×32 at 144 dpi, 18×18 at 72 dpi, 36×36 at 144 dpi). `TISIconIsTemplate` is true, and `tsInputMethodIconFileKey` plus each mode's `tsInputModeMenuIconFileKey` (and the alternate and palette keys) name this file. macOS tints the template for light and dark menu bars.
- `resources/paretly.pdf` — the same drawing as an 18×18 pt vector, the role `rime.pdf` has in Squirrel. It is copied into the app.
- `resources/AppIcon.icns` with every size macOS reads (16, 32, 64, 128, 256, 512, 1024, including the @2x types) and the same images in `Assets.xcassets/AppIcon.appiconset/`. `CFBundleIconFile` is `AppIcon.icns`. The input method and the Launchpad app in `/Applications` both use that file.

### Launchpad

The input method lives in `/Library/Input Methods` with `LSUIElement` set, so Launchpad does not list it. `make` compiles `launcher/main.swift` into `Paretly.app/Contents/Resources/ParetlyLauncher.tar`. `scripts/postinstall` unpacks that to `/Applications/Paretly.app`.

That app is a normal foreground bundle with the same icon and the name Paretly. If the input method is already running, the launcher asks it to open the existing settings window. If it is not running, the launcher starts it and that process opens settings. **Deploy** in the settings window calls the existing `deploy()`.

An alias to the input method would not show up in Launchpad: the target is outside the folders Launchpad scans, and opening the `LSUIElement` bundle does not present settings. The package also does not nest a second `.app` inside the input method, because `pkgbuild` would treat that as another relocatable bundle.

### Release

Push a `v*` tag on the commit you want to ship. The tag must be `v` plus two to four numeric components, such as `v0.1.0`. A tag like `v0.1.0-rc1` fails the version check.

GitHub Actions reuses the existing macOS job to build `package/Paretly.pkg` and copies it to `dist/Paretly-unsigned.pkg`. Every build sets `CFBundleVersion` and the package version to `github.run_number`, so a newer package replaces the one already installed. A tag also strips the leading `v` and sets `CFBundleShortVersionString` from that number. The workflow then publishes a GitHub Release with `GITHUB_TOKEN` (`contents: write`), attaches the pkg and `Paretly-unsigned.pkg.sha256` (from `sha256sum`), and uses GitHub's auto-generated notes. The package scripts stop the running input method, register it, and unpack the Launchpad app to `/Applications`.

The tag for the first release is `v0.1.0`, the matching entry in `CHANGELOG.md`. Pushing that tag is what creates the Release. Do not use `package/bump_version`; that leftover Squirrel script commits and creates a tag locally.

Pull requests only build the package. They keep the project marketing version `0.1.0`, set `CFBundleVersion` from that run's `github.run_number`, upload an artifact named `Paretly-unsigned.pkg`, and do not publish a Release.

A push to `main`, after the package build succeeds, also publishes a **prerelease**. It is never marked Latest and never uses a `v*` tag. The tag is `beta-<run number>` and the title is `<marketing version>-beta.<run number>`, for example `0.1.0-beta.42`. The assets are the same `Paretly-unsigned.pkg` and `.sha256`. Only the five newest betas are kept; older `beta-*` releases and tags are deleted. The stable `v*` release flow is unchanged.

### Updates

The input menu and the settings window (the Paretly app in Launchpad opens that window) both have **Check for Updates…**. Paretly reads the latest stable GitHub Release of `QiuZekun/paretly-ime` (drafts and prereleases are skipped) and compares the `vX.Y.Z` tag with `CFBundleShortVersionString`.

A newer release shows its notes and three buttons: **Update Now** (一键更新), **Later**, and **Skip this version**. The package is saved to `~/Downloads/Paretly-unsigned.pkg`. Paretly checks the file size and the SHA-256 digest, then asks for an administrator password and installs in place with `installer`. The package scripts stop Paretly, register the new copy, and open the input method again. If that fails, the package opens in Installer. The package is unsigned. The dialog explains Gatekeeper: right-click the package and choose Open, or choose Open Anyway in System Settings > Privacy & Security. If you are already up to date, it says so. When the repo has no published release, or GitHub returns 404 for the latest release, a manual check says you're up to date and that no newer version has been published yet (with the current version). That is not an error. Only a network or HTTP failure is reported, and the alert includes the reason. The input menu and the Settings button both run this check, and the alert is brought forward. An automatic check runs at most once a day on launch. The Settings switch for automatic checks defaults to on. Sparkle is not used for this: an unsigned package cannot go through Sparkle's EdDSA install path.

**Receive beta updates** (接收测试版（Beta）) defaults to off. A build produced from `main` defaults to on. When it is on, the check includes prereleases and compares the semver core, then the build number. On the same `0.1.0`, a beta with a higher build number is newer than the stable release; `0.2.0` is still newer than any `0.1.0-beta.N`.

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
