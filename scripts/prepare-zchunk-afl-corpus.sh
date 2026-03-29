#!/usr/bin/bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /absolute/path/to/zchunk-source [input-corpus-dir]" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_DIR="$1"
INPUT_DIR="${2:-$ROOT_DIR/fuzzing/zchunk/in}"
SOURCE_DIR="$TARGET_DIR/test/files"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Seed source directory does not exist: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$INPUT_DIR"

copied=0
while IFS= read -r sample; do
  cp -f "$sample" "$INPUT_DIR/"
  copied=$((copied + 1))
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.zck' | sort)

if [[ "$copied" -eq 0 ]]; then
  echo "No .zck files were found under $SOURCE_DIR" >&2
  exit 1
fi

echo "Prepared AFL++ input corpus:"
echo "  source dir: $SOURCE_DIR"
echo "  input dir:  $INPUT_DIR"
echo "  files:      $copied"
