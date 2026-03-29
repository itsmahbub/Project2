#!/usr/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT_DIR="${1:-$ROOT_DIR/fuzzing/zchunk/out}"
STATS_FILE="$OUTPUT_DIR/default/fuzzer_stats"
QUEUE_DIR="$OUTPUT_DIR/default/queue"
CRASH_DIR="$OUTPUT_DIR/default/crashes"
HANG_DIR="$OUTPUT_DIR/default/hangs"

if [[ ! -f "$STATS_FILE" ]]; then
  echo "AFL++ stats file not found: $STATS_FILE" >&2
  exit 1
fi

read_stat() {
  local key="$1"
  awk -F: -v target="$key" '$1 == target {gsub(/^[ \t]+/, "", $2); print $2}' "$STATS_FILE"
}

count_dir_files() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    find "$dir" -type f ! -name 'README.txt' | wc -l | tr -d ' '
  else
    echo 0
  fi
}

echo "AFL++ output summary:"
echo "  stats file:      $STATS_FILE"
echo "  run time:        $(read_stat run_time)s"
echo "  execs done:      $(read_stat execs_done)"
echo "  execs/sec:       $(read_stat execs_per_sec)"
echo "  corpus count:    $(read_stat corpus_count)"
echo "  corpus found:    $(read_stat corpus_found)"
echo "  coverage:        $(read_stat bitmap_cvg)"
echo "  stability:       $(read_stat stability)"
echo "  queue files:     $(count_dir_files "$QUEUE_DIR")"
echo "  crashes:         $(count_dir_files "$CRASH_DIR")"
echo "  hangs:           $(count_dir_files "$HANG_DIR")"
