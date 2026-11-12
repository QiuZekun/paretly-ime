# 第三方声明 / Third-party notices

Paretly 以 **GPL-3.0** 发布。许可证全文是仓库根目录的 `LICENSE.txt`。这是鼠须管的修改版，修改说明在 `NOTICE`。下面列出安装包里带上的组件、作者和许可证。`licenses/` 里的文件是对应上游许可证的原文，不要改。

Paretly is **GPL-3.0**. The license text is `LICENSE.txt`. `NOTICE` states that this tree modifies Squirrel. The files under `licenses/` are verbatim upstream license texts.

版本钉在这些提交上。构建时 `action-install.sh` 下载的是 librime **1.16.0** 的 macOS 预编译包（`rime-a251145-macOS-universal.tar.bz2`）和同一次发布的依赖包，再加上 Sparkle **2.6.2**。雾凇拼音的钉见 `versions/rime-ice.env`。

## 本程序

| 组件 | 作者 | 许可 | 说明 |
| --- | --- | --- | --- |
| Paretly | Paretly contributors, 2026 | GPL-3.0（`LICENSE.txt`） | 鼠须管的修改版。改动包括产品名、默认方案、未签名磁盘镜像、原生设置窗口 |
| [Squirrel / 鼠须管 / 鼠鬚管](https://github.com/rime/squirrel) | Rime 开发者（式恕堂）。程序：佛振、Linghua Zhang、Chongyu Zhu、雪齋、faberii、Chun-wei Kuo、Junlu Cheng、Jak Wings、xiehuc。图标：佛振、梁海、雨过之后。配色：Aben、Chongyu Zhu、skoj、Superoutman、佛振、梁海 | GPL-3.0 | 上游稳定版 tag `1.1.2`，提交 `876adebaf2f612951dcdca8a591de65401222b9a`。源文件里的版权声明保留 |
| [Rime / 中州韵](https://rime.im) | Rime 开发者 | 见各组件 | 输入法引擎 |
| [Rime ICE / 雾凇拼音](https://github.com/iDvel/rime-ice) | Dvel | **GPL-3.0 only** | 随包默认方案。tag `2026.06.30`，提交 `6810e8916d160498620a16fef2135956fecbd485`。词典、Lua 脚本和它自带的 OpenCC 数据一起放在 `Contents/SharedSupport`，文件里的版权声明保留。上游写明是 GPL-3.0 only，不是“或更新版本” |

鼠须管的致谢原文在上游 README。这里照它的作者名单列出，不另作增减。

## 引擎和插件

这些库编进 `Paretly.app`，或作为 `rime-plugins` 动态库放进包里。预编译包里的 `version-info.txt` 写明插件是 `hchunhui/librime-lua`、`lotem/librime-octagram`、`rime/librime-predict`。

| 组件 | 提交 | 许可 | 原文 |
| --- | --- | --- | --- |
| [librime](https://github.com/rime/librime) | `a251145d3aafa33871824a40bbec04c966bd8b56` | BSD 3-Clause。Copyright (c) 2014, RIME Developers | `licenses/librime-BSD-3-Clause.txt` |
| [librime-lua](https://github.com/hchunhui/librime-lua) | `68f9c36` | BSD 3-Clause。Copyright (c) 2021, librime-lua Developers | `licenses/librime-lua-BSD-3-Clause.txt` |
| [Lua 5.4.8](https://www.lua.org) | librime-lua `thirdparty` 在 librime 1.16.0 发布时（2026-01-06）的 `lua5.4`，提交 `fa40fad` | MIT。Copyright (C) 1994-2025 Lua.org, PUC-Rio | `licenses/lua-MIT.txt` |
| [librime-octagram](https://github.com/lotem/librime-octagram) | `dfcc151` | GPL-3.0，与 `LICENSE.txt` 同一许可证 | `LICENSE.txt` |
| [librime-predict](https://github.com/rime/librime-predict) | `920bd41` | BSD 3-Clause。Copyright (c) 2023, RIME Developers | `licenses/librime-predict-BSD-3-Clause.txt` |

## librime 链接的库

librime 1.16.0 的依赖，以及 OpenCC 带上的库。静态库随引擎链进程序。BSD 和 MIT 要求二进制分发保留版权声明和许可条款，原文在 `licenses/`。

| 组件 | 提交 | 许可 | 原文 |
| --- | --- | --- | --- |
| [Boost](https://www.boost.org/) | librime 文档中的运行时依赖 | Boost Software License 1.0 | `licenses/Boost-Software-License-1.0.txt` |
| [google-glog](https://github.com/google/glog) | `7b134a5c82c0c0b5698bb6bf7a835b230c5638e4` | BSD 3-Clause。Copyright (c) 2024, Google Inc. | `licenses/glog-BSD-3-Clause.txt` |
| [LevelDB](https://github.com/google/leveldb) | `99b3c03b3284f5886f9ef9a4ef703d57373e61be` | BSD 3-Clause。Copyright (c) 2011 The LevelDB Authors | `licenses/leveldb-BSD-3-Clause.txt` |
| [marisa-trie](https://github.com/s-yata/marisa-trie) | `3e87d53b78e15f2f43783d5e376561a8c9722051` | BSD-2-Clause **或** LGPL-2.1-or-later。Copyright (c) 2010-2025, Susumu Yata。两份声明都保留 | `licenses/marisa-trie-COPYING.md` |
| [OpenCC / 开放中文转换](https://github.com/BYVoid/OpenCC) | `556ed22496d650bd0b13b6c163be9814637970ae` | Apache-2.0。作者 Carbo Kuo，贡献者见该提交的 `AUTHORS` | `licenses/Apache-2.0.txt` |
| [yaml-cpp](https://github.com/jbeder/yaml-cpp) | `2f86d13775d119edbb69af52e5f566fd65c6953b` | MIT。Copyright (c) 2008-2015 Jesse Beder | `licenses/yaml-cpp-MIT.txt` |
| [darts-clone](http://darts-clone.googlecode.com/) | OpenCC 依赖，声明来自 librime 依赖包里的 `include/COPYING.darts-clone` | BSD。Copyright (c) 2008-2013, Susumu Yata。原文第三条款仍写着 `<ORGANIZATION>`，这里原样保留 | `licenses/darts-clone-BSD.txt` |
| [UTF8-CPP](https://github.com/nemtrif/utfcpp) | 头文件在同一依赖包的 `include/utf8.h` | Boost Software License 风格。Copyright 2006 Nemanja Trifunovic | `licenses/utf8-cpp-BSL.txt` |

## 数据和更新框架

| 组件 | 提交 | 许可 | 原文 |
| --- | --- | --- | --- |
| [plum / 东风破](https://github.com/rime/plum) | `4c28f11f451facef809b380502874a48ba964ddb` | LGPL-3.0。随包有 `rime-install` 和 plum 的默认配方数据 | `licenses/LGPL-3.0.txt`（并入 `LICENSE.txt` 的 GPL-3.0 条款） |
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.6.2 | `41847a58cdef7506b257591fcca6f9495df591d4` | MIT。自动更新没有打开。框架还带有 bsdiff（Colin Percival）、sais-lite（Yuta Mori）、ed25519（Orson Peters）和 `SUSignatureVerifier.m`（Mark Hamlin），声明都在同一份许可证里 | `licenses/Sparkle-LICENSE.txt` |

## 没有放进 App 的构建依赖

[Google Test](https://github.com/google/googletest)（librime 子模块 `f8d7d77c06936315286eb55f8de22cd23c188571`，BSD 3-Clause）只在构建 librime 时使用，不放进 `Paretly.app`。

## English

Paretly is a 2026 modification of Squirrel 1.1.2 (`876adebaf2f612951dcdca8a591de65401222b9a`) and is GPL-3.0. See `NOTICE` and `LICENSE.txt`. Program authors recorded by Squirrel are 佛振, Linghua Zhang, Chongyu Zhu, 雪齋, faberii, Chun-wei Kuo, Junlu Cheng, Jak Wings, and xiehuc. Icon and color-scheme credits are in the table above and in the upstream Squirrel README.

Rime ICE (雾凇拼音) by Dvel is shipped as the default schema, tag `2026.06.30`, commit `6810e8916d160498620a16fef2135956fecbd485`, under **GPL-3.0 only**. Its dictionaries, Lua scripts, OpenCC data, and the notices inside those files are copied into SharedSupport.

The app links or bundles librime (BSD 3-Clause), librime-lua (BSD 3-Clause) with Lua 5.4.8 (MIT), librime-octagram (GPL-3.0), librime-predict (BSD 3-Clause), Boost (BSL-1.0), glog, LevelDB, marisa-trie (BSD-2-Clause or LGPL-2.1-or-later), OpenCC (Apache-2.0), yaml-cpp (MIT), darts-clone, UTF8-CPP, plum (LGPL-3.0), and Sparkle 2.6.2 (MIT, including the external notices in its license). Pins and the verbatim texts are in the tables above. Google Test is a librime build dependency and is not copied into the app.
