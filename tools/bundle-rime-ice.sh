#!/usr/bin/env bash
# Copy the pinned rime-ice data into an already-built Paretly.app.
# Plum's default.yaml is overwritten so the first schema is rime_ice.
# The frontend file paretly.yaml stays the one compiled into the app.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?usage: bundle-rime-ice.sh /path/to/Paretly.app}"
src="${root}/data/rime-ice"
dest="${app}/Contents/SharedSupport"

if [[ ! -f "${src}/rime_ice.schema.yaml" || ! -f "${src}/default.yaml" ]]; then
  echo "rime-ice data is missing. Run: bash tools/update-rime-ice.sh" >&2
  exit 1
fi

if [[ ! -d "${dest}" ]]; then
  echo "SharedSupport is missing: ${dest}" >&2
  exit 1
fi

# Merge into SharedSupport. Keep files the Xcode build already copied
# (paretly.yaml, OpenCC dictionaries) when rime-ice does not replace them.
shopt -s nullglob
for item in "${src}"/*; do
  base="$(basename "${item}")"
  case "${base}" in
    squirrel.yaml|weasel.yaml|recipe.yaml) continue ;;
  esac
  if [[ -d "${item}" ]]; then
    mkdir -p "${dest}/${base}"
    cp -R "${item}/." "${dest}/${base}/"
  else
    cp "${item}" "${dest}/${base}"
  fi
done
rm -f "${dest}/squirrel.yaml" "${dest}/weasel.yaml" "${dest}/recipe.yaml"

python3 - "${dest}/default.yaml" << 'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
first = None
in_list = False
for line in text.splitlines():
    if line.startswith("schema_list:"):
        in_list = True
        continue
    if not in_list:
        continue
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if stripped.startswith("- schema:"):
        first = stripped.split(":", 1)[1].split("#", 1)[0].strip()
        break
    if not line.startswith((" ", "\t", "-")):
        break
if first != "rime_ice":
    sys.exit(f"SharedSupport default.yaml selects {first!r}, expected rime_ice")
print("SharedSupport default schema:", first)
PY

test -f "${dest}/paretly.yaml"
test -f "${dest}/rime_ice.schema.yaml"
test -f "${dest}/cn_dicts/base.dict.yaml"
test -f "${dest}/lua/date_translator.lua"
test -f "${dest}/opencc/emoji.json"
test ! -e "${dest}/squirrel.yaml"

executable="${app}/Contents/MacOS/Paretly"
if [[ ! -f "${executable}" ]]; then
  echo "Paretly executable is missing: ${executable}" >&2
  exit 1
fi

if command -v plutil >/dev/null 2>&1; then
  if ! plutil -extract CFBundleExecutable raw -o - "${app}/Contents/Info.plist" | grep -qx 'Paretly'; then
    echo "CFBundleExecutable is not Paretly" >&2
    exit 1
  fi
  if ! plutil -extract CFBundleIdentifier raw -o - "${app}/Contents/Info.plist" | grep -qx 'com.qiuzekun.inputmethod.Paretly'; then
    echo "CFBundleIdentifier is not com.qiuzekun.inputmethod.Paretly" >&2
    exit 1
  fi
  if ! plutil -extract InputMethodConnectionName raw -o - "${app}/Contents/Info.plist" | grep -qx 'Paretly_Connection'; then
    echo "InputMethodConnectionName is not Paretly_Connection" >&2
    exit 1
  fi
else
  echo "plutil is not available; skipped Info.plist checks" >&2
fi

echo "Bundled rime-ice into ${dest}"
