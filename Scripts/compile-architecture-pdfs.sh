#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lumap_root="$(cd "${script_dir}/.." && pwd)"
source_dir="${lumap_root}/docs/latex"
build_root="${lumap_root}/.build/latex"
output_dir="${LUMAP_PDF_OUTPUT_DIR:-${lumap_root}/docs/pdf}"

if ! command -v tectonic >/dev/null 2>&1; then
  echo "Tectonic is required. Install it with: brew install tectonic" >&2
  exit 1
fi

mkdir -p "${build_root}/rl" "${build_root}/system" "${output_dir}"

compile_document() {
  local base_name="$1"
  local build_dir="$2"
  local source_file="${source_dir}/${base_name}.tex"

  [[ -f "${source_file}" ]] || {
    echo "Missing LaTeX source: ${source_file}" >&2
    exit 1
  }

  tectonic --keep-logs --outdir "${build_dir}" "${source_file}"
  install -m 0644 "${build_dir}/${base_name}.pdf" "${output_dir}/${base_name}.pdf"
}

compile_document "Lumap_RL_Recommendation_Architecture" "${build_root}/rl"
compile_document "Lumap_System_Architecture" "${build_root}/system"

echo "Compiled LaTeX PDFs:"
echo "${output_dir}/Lumap_RL_Recommendation_Architecture.pdf"
echo "${output_dir}/Lumap_System_Architecture.pdf"
