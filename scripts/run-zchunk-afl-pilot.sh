#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DURATION_SECONDS="${1:-120}"
TARGET_DIR="${2:-$ROOT_DIR/targets/zchunk}"
INPUT_DIR="${3:-$ROOT_DIR/fuzzing/zchunk/in}"
OUTPUT_DIR="${4:-$ROOT_DIR/fuzzing/zchunk/out}"
BUILD_DIR_NAME="${5:-build-afl}"

if ! command -v timeout >/dev/null 2>&1; then
  echo "Required tool not found in PATH: timeout" >&2
  exit 1
fi

if [[ "$DURATION_SECONDS" -lt 1 ]]; then
  echo "Duration must be at least 1 second" >&2
  exit 1
fi

exec bash "$ROOT_DIR/scripts/run-zchunk-afl-target-pilot.sh" \
  "$DURATION_SECONDS" \
  "$TARGET_DIR" \
  "$INPUT_DIR" \
  "$OUTPUT_DIR" \
  "$BUILD_DIR_NAME" \
  unzck \
  -c
