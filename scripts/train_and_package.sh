#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${MODEL_VERSION:-}}"

if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <model-version>"
  echo "       or set MODEL_VERSION environment variable."
  exit 1
fi

OUTPUT_DIR="${ROOT_DIR}/output"
DIST_DIR="${ROOT_DIR}/dist"

rm -rf "${OUTPUT_DIR}" "${DIST_DIR}"
mkdir -p "${OUTPUT_DIR}" "${DIST_DIR}"

pushd "${ROOT_DIR}" > /dev/null

python src/read_data.py
python src/text_preprocessing.py
python src/text_classification.py

popd > /dev/null

declare -A FILES_TO_PACKAGE=(
  ["model"]="model.joblib"
  ["preprocessor"]="preprocessor.joblib"
  ["preprocessed_data"]="preprocessed_data.joblib"
  ["misclassified"]="misclassified_msgs.txt"
  ["accuracy_plot"]="accuracy_scores.png"
)

for key in "${!FILES_TO_PACKAGE[@]}"; do
  filename="${FILES_TO_PACKAGE[$key]}"
  src="${OUTPUT_DIR}/${filename}"
  if [[ -f "${src}" ]]; then
    base="${filename%.*}"
    ext=""
    if [[ "${filename}" == *.* ]]; then
      ext=".${filename##*.}"
    fi
    cp "${src}" "${DIST_DIR}/${base}-${VERSION}${ext}"
  fi
done

for artifact in model preprocessor preprocessed_data; do
  src="${OUTPUT_DIR}/${FILES_TO_PACKAGE[$artifact]}"
  if [[ ! -f "${src}" ]]; then
    echo "Expected artifact ${src} not found."
    exit 1
  fi
done

echo "Artifacts are available in ${DIST_DIR}"
