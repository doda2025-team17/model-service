#!/usr/bin/env bash
set -euo pipefail

# Ensure model directory exists and is writable if volumes are mounted
MODEL_DIR="${MODEL_DIR:-/models}"
mkdir -p "${MODEL_DIR}"

# Delegate to the Python app (which handles MODEL_URL/MODEL_FILES)
exec "$@"
