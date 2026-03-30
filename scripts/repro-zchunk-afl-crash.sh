#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /absolute/path/to/crash-file [/absolute/path/to/zchunk-source] [build-dir-name] [target-name] [target-arg ...]" >&2
  exit 1
fi

CRASH_FILE="$1"
TARGET_DIR="${2:-$ROOT_DIR/targets/zchunk}"
BUILD_DIR_NAME="${3:-build-afl}"
TARGET_NAME="${4:-unzck}"

if [[ $# -ge 4 ]]; then
  shift 4
  TARGET_ARGS=("$@")
else
  TARGET_ARGS=()
fi

if [[ "$TARGET_NAME" == "unzck" && "${#TARGET_ARGS[@]}" -eq 0 ]]; then
  TARGET_ARGS=(-c)
fi

TARGET_BIN="$TARGET_DIR/$BUILD_DIR_NAME/src/$TARGET_NAME"

if [[ ! -f "$CRASH_FILE" ]]; then
  echo "Crash file does not exist: $CRASH_FILE" >&2
  exit 1
fi

if [[ ! -x "$TARGET_BIN" ]]; then
  echo "Instrumented target not found at $TARGET_BIN" >&2
  echo "Run scripts/build-zchunk-afl.sh first." >&2
  exit 1
fi

echo "Reproducing crash with:"
echo "  target: $TARGET_BIN"
if [[ "${#TARGET_ARGS[@]}" -gt 0 ]]; then
  echo "  args:   ${TARGET_ARGS[*]}"
fi
echo "  input:  $CRASH_FILE"

"$TARGET_BIN" "${TARGET_ARGS[@]}" "$CRASH_FILE" >/dev/null
