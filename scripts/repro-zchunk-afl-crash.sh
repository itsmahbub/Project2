#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 /absolute/path/to/crash-file [/absolute/path/to/zchunk-source] [build-dir-name]" >&2
  exit 1
fi

CRASH_FILE="$1"
TARGET_DIR="${2:-$ROOT_DIR/targets/zchunk}"
BUILD_DIR_NAME="${3:-build-afl}"
TARGET_BIN="$TARGET_DIR/$BUILD_DIR_NAME/src/unzck"

if [[ ! -f "$CRASH_FILE" ]]; then
  echo "Crash file does not exist: $CRASH_FILE" >&2
  exit 1
fi

if [[ ! -x "$TARGET_BIN" ]]; then
  echo "Instrumented target not found at $TARGET_BIN" >&2
  echo "Run scripts/build-zchunk-afl.sh first." >&2
  exit 1
fi

"$TARGET_BIN" -c "$CRASH_FILE" >/dev/null
