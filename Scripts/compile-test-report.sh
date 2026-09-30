#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lumap_root="$(cd "${script_dir}/.." && pwd)"
repo_root="$(cd "${lumap_root}/.." && pwd)"
source_dir="${lumap_root}/docs/latex"
source_file="${source_dir}/Lumap_Full_Function_Test_Report.tex"
build_dir="${lumap_root}/.build/latex/test-report"
output_dir="${repo_root}/output/pdf"
output_file="${output_dir}/Lumap_Full_Function_Test_Report.pdf"
log_file="${build_dir}/Lumap_Full_Function_Test_Report.log"
evidence_root="${lumap_root}/docs/test-evidence/2026-09-30"

if ! command -v tectonic >/dev/null 2>&1; then
  echo "Tectonic is required. Install it with: brew install tectonic" >&2
  exit 1
fi

[[ -f "${source_file}" ]] || {
  echo "Missing LaTeX source: ${source_file}" >&2
  exit 1
}

required_evidence=(
  mac/01-discover.jpg
  mac/02-learning-studio-guided.jpg
  mac/03-all-methods-menu.jpg
  mac/method-02-worked-example.jpg
  mac/method-03-socratic.jpg
  mac/method-04-analogy.jpg
  mac/method-05-visual-map.jpg
  mac/method-06-story-mode.jpg
  mac/method-07-flash-recall.jpg
  mac/method-08-teach-back.jpg
  mac/method-09-simulation.jpg
  mac/method-10-spatial-ar.jpg
  mac/method-11-deliberate-practice.jpg
  mac/method-12-reflection.jpg
  mac/method-13-misconception.jpg
  mac/method-14-curiosity.jpg
  ios/01-ios-discover.jpg
  ios/02-ios-learn.jpg
  ios/03-ios-methods-top.jpg
  ios/04-ios-methods-bottom.jpg
  ios/05-ios-spatial-fallback.jpg
  ios/07-ios-narrated-deck.jpg
  ios/08-ios-narrated-preview.jpg
  ios/09-ios-narrated-quiz.jpg
  ios/10-ios-personal.jpg
  ios/11-ios-settings-top.jpg
  ios/12-ios-settings-provider.jpg
  ios/13-ios-counterfactual.jpg
  ios/14-ios-transfer.jpg
  ios/15-ios-guided-study.jpg
  ios/16-ios-guided-question.jpg
  ios/17-ios-future-knowledge.jpg
  ios/18-ios-future-spatial.jpg
  ios/19-ios-future-rl.jpg
  ios/20-ios-future-handoff.jpg
  ios/21-ios-future-social.jpg
)

missing_evidence=()
for relative_path in "${required_evidence[@]}"; do
  [[ -s "${evidence_root}/${relative_path}" ]] || missing_evidence+=("${relative_path}")
done
if (( ${#missing_evidence[@]} > 0 )); then
  printf 'Missing required one-image-per-page evidence:\n' >&2
  printf '  %s\n' "${missing_evidence[@]}" >&2
  exit 1
fi

mkdir -p "${build_dir}" "${output_dir}"
rm -f "${build_dir}/Lumap_Full_Function_Test_Report."{aux,log,out,pdf,toc}

(
  cd "${source_dir}"
  tectonic --keep-logs --keep-intermediates \
    --outdir "${build_dir}" \
    "${source_file}"
)

if [[ ! -s "${build_dir}/Lumap_Full_Function_Test_Report.pdf" ]]; then
  echo "Tectonic did not create the expected PDF." >&2
  exit 1
fi

if [[ -f "${log_file}" ]] && grep -E '(Overfull|Underfull) \\[hv]box' "${log_file}"; then
  echo "LaTeX box warnings must be fixed before delivery." >&2
  exit 1
fi

install -m 0644 "${build_dir}/Lumap_Full_Function_Test_Report.pdf" "${output_file}"

python3 - "${output_file}" <<'PY'
from pathlib import Path
import sys

pdf_path = Path(sys.argv[1])
try:
    from pypdf import PdfReader
except ImportError:
    print("pypdf unavailable; skipped semantic PDF validation.")
    raise SystemExit(0)

reader = PdfReader(str(pdf_path))
if len(reader.pages) < 45:
    raise SystemExit(f"Unexpectedly short report: {len(reader.pages)} pages")

page_texts = [(page.extract_text() or "").strip() for page in reader.pages]
blank_pages = [index + 1 for index, text in enumerate(page_texts) if len(text) < 20]
if blank_pages:
    raise SystemExit(f"Blank or unreadable pages detected: {blank_pages}")

text = "\n".join(page_texts)
required = [
    "Lumap 全功能测试报告",
    "1.1-final",
    "22 项单元测试覆盖范围",
    "17 种学习方法逐项结果",
    "Guided Study / Inquiry route",
    "M-01",
    "M-17",
    "iOS Simulator 截图证据",
    "Surprise retrieval",
    "当前未实现",
    "Knowledge Studio / multi-source citations",
    "Spatial glasses / AR concept",
    "LumaPath-RL adaptive path",
    "Cross-device learning handoff",
    "Social interest constellation",
    "交互概念 / demo data",
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit(f"Required report text is missing: {missing}")

forbidden = ["截图待本轮手工补充", "1.0-draft"]
unexpected = [item for item in forbidden if item in text]
if unexpected:
    raise SystemExit(f"Draft markers remain in final report: {unexpected}")

evidence_pages = {}
for number in range(1, 37):
    marker = f"E-{number:02d}"
    pages = [index + 1 for index, page_text in enumerate(page_texts) if marker in page_text]
    if len(pages) != 1:
        raise SystemExit(f"Evidence marker {marker} must occur on exactly one page; found {pages}")
    evidence_pages[marker] = pages[0]

if len(set(evidence_pages.values())) != 36:
    collisions = {}
    for marker, page in evidence_pages.items():
        collisions.setdefault(page, []).append(marker)
    collisions = {page: markers for page, markers in collisions.items() if len(markers) > 1}
    raise SystemExit(f"More than one evidence image is assigned to a page: {collisions}")

for marker, page in evidence_pages.items():
    page_text = page_texts[page - 1]
    required_labels = ["画面证据", "证据边界"]
    missing_labels = [label for label in required_labels if label not in page_text]
    if missing_labels:
        raise SystemExit(f"Evidence page {marker} is missing labels: {missing_labels}")

print(
    f"Validated {len(reader.pages)} pages; no blank pages; required sections present; "
    "36 evidence images occupy 36 distinct pages."
)
PY

echo "Compiled test report:"
echo "${output_file}"
