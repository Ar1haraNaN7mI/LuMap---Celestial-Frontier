#!/usr/bin/env bash

set -euo pipefail

readonly pack_id="kokoro-int8-multi-lang-v1_1"
readonly archive_name="${pack_id}.tar.bz2"
readonly source_url="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/${archive_name}"
readonly expected_sha256="a1e94694776049035c4f2c6529f003aaece993c76aae9a78995831c3c4dcafc6"
readonly expected_archive_bytes="147031220"
readonly expected_model_bytes="114299010"
readonly expected_voices_bytes="53790720"

default_root="${HOME}/Library/Containers/com.local.lumap/Data/Library/Application Support/Lumap/VoicePacks"
destination_root="${LUMAP_VOICE_PACK_DIR:-${default_root}}"
archive_path=""

usage() {
  cat <<'EOF'
Install Lumap's open-source Kokoro narration pack.

Usage:
  Scripts/install-kokoro-voice-pack.sh [--destination DIRECTORY] [--archive FILE]

Options:
  --destination DIRECTORY  VoicePacks parent directory. Defaults to the
                           macOS sandbox container for com.local.lumap.
  --archive FILE           Use an already-downloaded archive after verifying it.
  -h, --help               Show this help.

The script never installs or invokes Apple system voices. It downloads only
the pinned official k2-fsa release and verifies its SHA-256 digest.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destination)
      [[ $# -ge 2 ]] || { echo "Missing value for --destination" >&2; exit 2; }
      destination_root="$2"
      shift 2
      ;;
    --archive)
      [[ $# -ge 2 ]] || { echo "Missing value for --archive" >&2; exit 2; }
      archive_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

file_size() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

validate_pack() {
  local candidate="$1"
  local required
  for required in \
    model.int8.onnx voices.bin tokens.txt lexicon-us-en.txt lexicon-zh.txt \
    date-zh.fst number-zh.fst phone-zh.fst LICENSE; do
    [[ -f "${candidate}/${required}" ]] || return 1
  done
  [[ -d "${candidate}/espeak-ng-data" ]] || return 1
  [[ "$(file_size "${candidate}/model.int8.onnx")" == "${expected_model_bytes}" ]] || return 1
  [[ "$(file_size "${candidate}/voices.bin")" == "${expected_voices_bytes}" ]] || return 1
}

final_path="${destination_root}/${pack_id}"
if validate_pack "${final_path}"; then
  echo "Kokoro voice pack is already installed and valid:"
  echo "${final_path}"
  exit 0
fi

if [[ -e "${final_path}" ]]; then
  echo "An incomplete voice pack already exists at ${final_path}." >&2
  echo "Move it aside manually, then run this installer again." >&2
  exit 1
fi

mkdir -p "${destination_root}"

if [[ -z "${archive_path}" ]]; then
  cache_root="${TMPDIR:-/tmp}/lumap-voice-pack-downloads"
  mkdir -p "${cache_root}"
  archive_path="${cache_root}/${archive_name}"
  echo "Downloading the pinned open-source voice pack (about 147 MB)…"
  curl --location --fail --show-error --continue-at - \
    --output "${archive_path}" "${source_url}"
fi

[[ -f "${archive_path}" ]] || { echo "Archive not found: ${archive_path}" >&2; exit 1; }

actual_archive_bytes="$(file_size "${archive_path}")"
if [[ "${actual_archive_bytes}" != "${expected_archive_bytes}" ]]; then
  echo "Archive size mismatch: expected ${expected_archive_bytes}, got ${actual_archive_bytes}." >&2
  exit 1
fi

actual_sha256="$(shasum -a 256 "${archive_path}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
  echo "SHA-256 mismatch. Refusing to extract the voice pack." >&2
  exit 1
fi

if tar -tjf "${archive_path}" | awk '
  /^\// { unsafe = 1 }
  /(^|\/)\.\.($|\/)/ { unsafe = 1 }
  END { exit unsafe ? 0 : 1 }
'; then
  echo "Archive contains an unsafe path. Refusing to extract it." >&2
  exit 1
fi

staging_root="${destination_root}/.installing-${pack_id}-$$"
mkdir -p "${staging_root}"
tar -xjf "${archive_path}" -C "${staging_root}"
extracted_path="${staging_root}/${pack_id}"

if ! validate_pack "${extracted_path}"; then
  echo "Extracted pack is incomplete or has unexpected model sizes." >&2
  echo "Staging files were left for inspection at ${staging_root}." >&2
  exit 1
fi

mv "${extracted_path}" "${final_path}"
rmdir "${staging_root}"

cat > "${final_path}/.lumap-install.json" <<EOF
{
  "id": "${pack_id}",
  "archiveSHA256": "${actual_sha256}",
  "source": "${source_url}",
  "installedAtUTC": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF

echo "Installed and verified Kokoro voice pack:"
echo "${final_path}"
echo "The pack remains local and is not committed to Git."
