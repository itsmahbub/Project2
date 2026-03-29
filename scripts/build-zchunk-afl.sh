#!/usr/bin/bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /absolute/path/to/zchunk-source [build-dir-name]" >&2
  exit 1
fi

TARGET_DIR="$1"
BUILD_DIR_NAME="${2:-build-afl}"
BUILD_DIR="$TARGET_DIR/$BUILD_DIR_NAME"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

for tool in meson ninja afl-clang-fast afl-clang-fast++; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool not found in PATH: $tool" >&2
    exit 1
  fi
done

: "${CC:=afl-clang-fast}"
: "${CXX:=afl-clang-fast++}"
: "${CFLAGS:=-O1 -g -fno-omit-frame-pointer}"
: "${CXXFLAGS:=-O1 -g -fno-omit-frame-pointer}"

export CC
export CXX
export CFLAGS
export CXXFLAGS

cd "$TARGET_DIR"
rm -rf "$BUILD_DIR"
meson setup "$BUILD_DIR" . --buildtype=debug
ninja -C "$BUILD_DIR"

echo "AFL++ build complete:"
echo "  build dir: $BUILD_DIR"
echo "  target:    $BUILD_DIR/src/unzck"
