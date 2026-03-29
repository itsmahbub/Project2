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

RUNTIME_BASE="${JOURNALOT_AFL_RUNTIME:-/tmp/journalot-afl-date}"
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

if [[ ! -d "$JOURNAL_DIR/.git" ]]; then
  (
    cd "$JOURNAL_DIR"
    git init -q
    git config user.name "AFL Harness"
    git config user.email "afl@example.invalid"
    printf "*.swp\n.DS_Store\n" > .gitignore
    git add .gitignore
    git commit -q -m "Initial commit"
  )
fi

export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$XDG_DIR"
export JOURNAL_DIR="$JOURNAL_DIR"
export EDITOR=true
export TERM=dumb

bash "$TARGET_DIR/bin/journal" --date "$PAYLOAD" >/dev/null 2>&1
