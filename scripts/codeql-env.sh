#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CODEQL_BIN="$ROOT_DIR/tools/codeql/codeql"

if [[ ! -x "$CODEQL_BIN" ]]; then
  echo "CodeQL not found at $CODEQL_BIN" >&2
  echo "Follow docs/CODEQL_SETUP.md to install the CodeQL bundle into tools/codeql." >&2
  exit 1
fi

export PATH="$ROOT_DIR/tools/codeql:$PATH"
echo "CodeQL ready: $CODEQL_BIN"
"$CODEQL_BIN" version
