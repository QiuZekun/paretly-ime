# Upstream base

Paretly starts from [Squirrel](https://github.com/rime/squirrel) (鼠须管 / 鼠鬚管), the Rime frontend for macOS.

| Item | Value |
| --- | --- |
| Upstream | https://github.com/rime/squirrel |
| Stable tag | `1.1.2` |
| Commit | `876adebaf2f612951dcdca8a591de65401222b9a` |
| License | GPL-3.0 (`LICENSE.txt`, unchanged) |
| librime submodule | `a251145d3aafa33871824a40bbec04c966bd8b56` |
| librime prebuilt | Squirrel `action-install.sh` downloads librime **1.16.0** (`rime-a251145-macOS-universal.tar.bz2`) plus the matching deps archive and Sparkle 2.6.2. That is the same path Squirrel's own CI uses. |
| plum submodule | `4c28f11f451facef809b380502874a48ba964ddb` |
| Sparkle submodule | `41847a58cdef7506b257591fcca6f9495df591d4` |

The Squirrel git history is preserved in this repository. Tag `1.1.2` points at the upstream commit.

Upstream's GitHub workflows are not kept on this fork. They build and publish Squirrel installers (including a nightly release job aimed at `rime/squirrel`). Paretly's own build is added separately.
