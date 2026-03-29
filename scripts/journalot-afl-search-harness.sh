#!/usr/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /absolute/path/to/journalot-source /absolute/path/to/input-file" >&2
  exit 1
fi

TARGET_DIR="$1"
INPUT_FILE="$2"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file does not exist: $INPUT_FILE" >&2
  exit 1
fi

PAYLOAD=$(tr -d '\r' < "$INPUT_FILE" | head -c 256)
PAYLOAD=${PAYLOAD//$'\n'/ }

RUNTIME_BASE="${JOURNALOT_AFL_RUNTIME:-/tmp/journalot-afl-search}"
HOME_DIR="$RUNTIME_BASE/home"
XDG_DIR="$RUNTIME_BASE/xdg"
JOURNAL_DIR="$RUNTIME_BASE/journal"
CONFIG_DIR="$XDG_DIR/journalot"
CONFIG_FILE="$CONFIG_DIR/config"

mkdir -p "$CONFIG_DIR" "$JOURNAL_DIR/entries"

cat > "$CONFIG_FILE" <<EOF
AUTOSYNC=false
DISABLE_PROMPTS=true
MULTI_JOURNAL=false
GIT_BRANCH=main
EOF

cat > "$JOURNAL_DIR/entries/2026-03-28.md" <<'EOF'
# 2026-03-28

Worked on fuzzing notes today.
Confidence is growing.
#work
EOF

cat > "$JOURNAL_DIR/entries/2026-03-29.md" <<'EOF'
# 2026-03-29

Journalot search target seed entry.
#tag
EOF

export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$XDG_DIR"
export JOURNAL_DIR="$JOURNAL_DIR"
export EDITOR=true
export TERM=dumb

bash "$TARGET_DIR/bin/journal" --search "$PAYLOAD" >/dev/null 2>&1
