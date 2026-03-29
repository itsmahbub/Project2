#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_DIR="$ROOT_DIR/targets/zchunk"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target repo not found at $TARGET_DIR" >&2
  echo "Clone it first: git clone https://github.com/zchunk/zchunk.git $TARGET_DIR" >&2
  exit 1
fi

"$ROOT_DIR/scripts/run-codeql-cpp.sh" "$TARGET_DIR" "$ROOT_DIR/scripts/build-zchunk.sh $TARGET_DIR" "zchunk-linux"
