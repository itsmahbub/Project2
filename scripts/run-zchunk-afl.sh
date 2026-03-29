#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_DIR="${1:-$ROOT_DIR/targets/zchunk}"
INPUT_DIR="${2:-$ROOT_DIR/fuzzing/zchunk/in}"
OUTPUT_DIR="${3:-$ROOT_DIR/fuzzing/zchunk/out}"
BUILD_DIR_NAME="${4:-build-afl}"

exec bash "$ROOT_DIR/scripts/run-zchunk-afl-target.sh" \
  "$TARGET_DIR" \
  "$INPUT_DIR" \
  "$OUTPUT_DIR" \
  "$BUILD_DIR_NAME" \
  unzck \
  -c
