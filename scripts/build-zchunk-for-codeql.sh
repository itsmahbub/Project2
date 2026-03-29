#!/usr/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /absolute/path/to/zchunk-source" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_DIR="$1"
COMPILE_DB="$TARGET_DIR/build/compile_commands.json"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

if [[ ! -f "$COMPILE_DB" ]]; then
  echo "Missing compile_commands.json at $COMPILE_DB" >&2
  echo "Run $ROOT_DIR/scripts/prepare-zchunk-build.sh $TARGET_DIR first." >&2
  exit 1
fi

"$ROOT_DIR/scripts/replay-compile-commands.py" "$COMPILE_DB"
