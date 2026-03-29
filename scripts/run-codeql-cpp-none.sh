#!/usr/bin/bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /absolute/path/to/source-root [database-name]" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CODEQL_BIN="$ROOT_DIR/tools/codeql/codeql"
SOURCE_ROOT="$1"
TARGET_NAME="${2:-$(basename "$SOURCE_ROOT")}"
DB_DIR="$ROOT_DIR/codeql/databases/${TARGET_NAME}-cpp"
RESULTS_DIR="$ROOT_DIR/codeql/results"
SARIF_OUT="$RESULTS_DIR/${TARGET_NAME}-cpp.sarif"

if [[ ! -x "$CODEQL_BIN" ]]; then
  echo "CodeQL not found at $CODEQL_BIN" >&2
  echo "Install it first using docs/CODEQL_SETUP.md." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_ROOT" ]]; then
  echo "Source root does not exist: $SOURCE_ROOT" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/codeql/databases" "$RESULTS_DIR"
rm -rf "$DB_DIR"

echo "[1/2] Creating CodeQL database at $DB_DIR"
"$CODEQL_BIN" database create "$DB_DIR" \
  --threads=1 \
  --language=cpp \
  --build-mode=none \
  --source-root="$SOURCE_ROOT"

echo "[2/2] Running C/C++ security-and-quality queries"
"$CODEQL_BIN" database analyze "$DB_DIR" \
  --threads=1 \
  codeql/cpp-queries:codeql-suites/cpp-security-and-quality.qls \
  --format=sarif-latest \
  --output="$SARIF_OUT"

echo "Database: $DB_DIR"
echo "Results:  $SARIF_OUT"
