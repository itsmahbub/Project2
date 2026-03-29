#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
MODE="${1:-date}"
OUTPUT_DIR="${2:-$ROOT_DIR/fuzzing/journalot/$MODE-in}"

mkdir -p "$OUTPUT_DIR"
find "$OUTPUT_DIR" -type f -delete

case "$MODE" in
  date)
    cat > "$OUTPUT_DIR/today.txt" <<'EOF'
today
EOF
    cat > "$OUTPUT_DIR/yesterday.txt" <<'EOF'
yesterday
EOF
    cat > "$OUTPUT_DIR/last-friday.txt" <<'EOF'
last friday
EOF
    cat > "$OUTPUT_DIR/three-days-ago.txt" <<'EOF'
3 days ago
EOF
    cat > "$OUTPUT_DIR/iso-date.txt" <<'EOF'
2025-01-15
EOF
    cat > "$OUTPUT_DIR/empty.txt" <<'EOF'

EOF
    ;;
  search)
    cat > "$OUTPUT_DIR/work.txt" <<'EOF'
work
EOF
    cat > "$OUTPUT_DIR/confidence.txt" <<'EOF'
confidence
EOF
    cat > "$OUTPUT_DIR/tag.txt" <<'EOF'
#tag
EOF
    cat > "$OUTPUT_DIR/date.txt" <<'EOF'
2025
EOF
    cat > "$OUTPUT_DIR/symbols.txt" <<'EOF'
[](){}.*
EOF
    cat > "$OUTPUT_DIR/empty.txt" <<'EOF'

EOF
    ;;
  *)
    echo "Unsupported mode: $MODE" >&2
    echo "Supported modes: date, search" >&2
    exit 1
    ;;
esac

echo "Prepared journalot AFL++ corpus:"
echo "  mode:      $MODE"
echo "  output dir:$OUTPUT_DIR"
echo "  files:     $(find "$OUTPUT_DIR" -type f | wc -l | tr -d ' ')"
