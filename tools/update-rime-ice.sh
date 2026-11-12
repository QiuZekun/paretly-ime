#!/usr/bin/env bash
# Download the pinned rime-ice checkout into data/rime-ice/.
# The directory is a build input and is not committed.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${root}/versions/rime-ice.env"

: "${RIME_ICE_TAG:?RIME_ICE_TAG is required}"
: "${RIME_ICE_COMMIT:?RIME_ICE_COMMIT is required}"

if [[ ! "${RIME_ICE_COMMIT}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "RIME_ICE_COMMIT must be a 40-character git sha, got: ${RIME_ICE_COMMIT}" >&2
  exit 1
fi

dest="${root}/data/rime-ice"
if [[ -f "${dest}/.commit" && "$(cat "${dest}/.commit")" == "${RIME_ICE_COMMIT}" && -f "${dest}/rime_ice.schema.yaml" ]]; then
  echo "rime-ice ${RIME_ICE_TAG} (${RIME_ICE_COMMIT}) already present"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

archive="${tmpdir}/rime-ice.tar.gz"
url="https://github.com/iDvel/rime-ice/archive/${RIME_ICE_COMMIT}.tar.gz"
echo "Downloading rime-ice ${RIME_ICE_TAG} from ${url}"
curl -fL --retry 3 --retry-delay 2 -o "${archive}" "${url}"
tar -xzf "${archive}" -C "${tmpdir}"

src=""
for dir in "${tmpdir}"/rime-ice-*; do
  if [[ -d "${dir}" ]]; then
    src="${dir}"
    break
  fi
done
if [[ -z "${src}" ]]; then
  echo "rime-ice archive did not contain a source directory" >&2
  exit 1
fi

rm -rf "${dest}"
mkdir -p "${dest}"

shopt -s nullglob
for file in "${src}"/*.yaml "${src}"/*.txt; do
  base="$(basename "${file}")"
  case "${base}" in
    squirrel.yaml|weasel.yaml|recipe.yaml) continue ;;
  esac
  cp "${file}" "${dest}/${base}"
done

for dir in cn_dicts en_dicts lua opencc; do
  if [[ ! -d "${src}/${dir}" ]]; then
    echo "rime-ice is missing ${dir}/" >&2
    exit 1
  fi
  cp -R "${src}/${dir}" "${dest}/${dir}"
done

printf '%s\n' "${RIME_ICE_COMMIT}" > "${dest}/.commit"
printf '%s\n' "${RIME_ICE_TAG}" > "${dest}/.tag"
cat > "${dest}/RIME_ICE_PIN.txt" << EOF
rime-ice ${RIME_ICE_TAG}
commit ${RIME_ICE_COMMIT}
source https://github.com/iDvel/rime-ice
license GPL-3.0-only
EOF

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
    sys.exit(f"rime-ice default.yaml selects {first!r}, expected rime_ice")
print("rime-ice default schema:", first)
PY

test -f "${dest}/rime_ice.schema.yaml"
test -f "${dest}/cn_dicts/base.dict.yaml"
test -f "${dest}/lua/date_translator.lua"
echo "Installed rime-ice ${RIME_ICE_TAG} (${RIME_ICE_COMMIT}) into ${dest}"
