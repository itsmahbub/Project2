#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
DURATION_SECONDS="${1:-120}"
TARGET_DIR="${2:-$ROOT_DIR/targets/zchunk}"
INPUT_DIR="${3:-$ROOT_DIR/fuzzing/zchunk/in}"
OUTPUT_DIR="${4:-$ROOT_DIR/fuzzing/zchunk/out}"
BUILD_DIR_NAME="${5:-build-afl}"
RUNTIME_DIR="$ROOT_DIR/fuzzing/zchunk/runtime"

if ! command -v timeout >/dev/null 2>&1; then
  echo "Required tool not found in PATH: timeout" >&2
  exit 1
fi

if [[ "$DURATION_SECONDS" -lt 1 ]]; then
  echo "Duration must be at least 1 second" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR" "$RUNTIME_DIR"

: "${AFL_NO_UI:=1}"
: "${AFL_SKIP_CPUFREQ:=1}"
: "${AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES:=1}"

export AFL_NO_UI
export AFL_SKIP_CPUFREQ
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES

echo "Starting AFL++ pilot run:"
echo "  duration:   ${DURATION_SECONDS}s"
echo "  target dir: $TARGET_DIR"
echo "  input dir:  $INPUT_DIR"
echo "  output dir: $OUTPUT_DIR"

set +e
timeout "${DURATION_SECONDS}s" \
  bash "$ROOT_DIR/scripts/run-zchunk-afl.sh" \
  "$TARGET_DIR" \
  "$INPUT_DIR" \
  "$OUTPUT_DIR" \
  "$BUILD_DIR_NAME"
status=$?
set -e

if [[ "$status" -ne 0 && "$status" -ne 124 ]]; then
  echo "Pilot run failed with exit code $status" >&2
  exit "$status"
fi

if [[ -f "$OUTPUT_DIR/default/fuzzer_stats" ]]; then
  bash "$ROOT_DIR/scripts/summarize-zchunk-afl-output.sh" "$OUTPUT_DIR"
else
  echo "Pilot run ended before AFL++ wrote fuzzer_stats" >&2
  exit 1
fi
