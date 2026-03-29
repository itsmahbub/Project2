#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_DIR="${1:-$ROOT_DIR/targets/zchunk}"
INPUT_DIR="${2:-$ROOT_DIR/fuzzing/zchunk/in}"
OUTPUT_DIR="${3:-$ROOT_DIR/fuzzing/zchunk/out}"
BUILD_DIR_NAME="${4:-build-afl}"
TARGET_NAME="${5:-unzck}"

shift $(( $# >= 4 ? 4 : $# ))
if [[ $# -gt 0 ]]; then
  shift
fi
TARGET_ARGS=("$@")

BUILD_DIR="$TARGET_DIR/$BUILD_DIR_NAME"
TARGET_BIN="$BUILD_DIR/src/$TARGET_NAME"
RUNTIME_DIR="$ROOT_DIR/fuzzing/zchunk/runtime-$TARGET_NAME"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input corpus directory does not exist: $INPUT_DIR" >&2
  echo "Run scripts/prepare-zchunk-afl-corpus.sh first." >&2
  exit 1
fi

if [[ ! -x "$TARGET_BIN" ]]; then
  echo "Instrumented target not found at $TARGET_BIN" >&2
  echo "Run scripts/build-zchunk-afl.sh first." >&2
  exit 1
fi

if ! command -v afl-fuzz >/dev/null 2>&1; then
  echo "Required tool not found in PATH: afl-fuzz" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$RUNTIME_DIR"

TIMEOUT_MS="${AFL_TIMEOUT_MS:-1000+}"
MEM_LIMIT="${AFL_MEM_LIMIT:-none}"

cd "$RUNTIME_DIR"

exec afl-fuzz \
  -i "$INPUT_DIR" \
  -o "$OUTPUT_DIR" \
  -m "$MEM_LIMIT" \
  -t "$TIMEOUT_MS" \
  -- \
  "$TARGET_BIN" "${TARGET_ARGS[@]}" @@
