#!/usr/bin/env bash
# jdb-diagnostics.sh — Collect diagnostics from a running JVM via JDB
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Collect diagnostics from a running JVM via JDB, including thread dumps,
class listings, and deadlock analysis. Outputs results to stdout or a file.

Options:
  --host <hostname>      Target host (default: localhost)
  --port <port>          JDWP port (default: 5005)
  --output <file>        Write diagnostics to file (default: stdout)
  --threads              Collect thread dump (default: enabled)
  --classes              List loaded classes (default: disabled, can be very large)
  --no-threads           Skip thread dump
  -h, --help             Show this help message

Prerequisites:
  The target JVM must have JDWP enabled:
    java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 ...

Examples:
  $(basename "$0") --port 5005
  $(basename "$0") --port 5005 --output /tmp/jvm-diagnostics.txt
  $(basename "$0") --port 8000 --classes

EOF
  exit 0
}

HOST="localhost"
PORT="5005"
OUTPUT=""
COLLECT_THREADS=true
COLLECT_CLASSES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --threads)
      COLLECT_THREADS=true
      shift
      ;;
    --no-threads)
      COLLECT_THREADS=false
      shift
      ;;
    --classes)
      COLLECT_CLASSES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Verify jdb is available
if ! command -v jdb &>/dev/null; then
  echo "Error: 'jdb' not found. Ensure the JDK is installed and on your PATH."
  exit 1
fi

# Build JDB commands to execute
JDB_COMMANDS=""

if $COLLECT_THREADS; then
  JDB_COMMANDS+="threads\n"
  JDB_COMMANDS+="where all\n"
fi

if $COLLECT_CLASSES; then
  JDB_COMMANDS+="classes\n"
fi

JDB_COMMANDS+="quit\n"

# Create a temp file for JDB input
TMPFILE=$(mktemp /tmp/jdb-diag-XXXXXX.txt)
printf "$JDB_COMMANDS" > "$TMPFILE"

HEADER="=== JVM Diagnostics ==="
HEADER+="\nHost: ${HOST}:${PORT}"
HEADER+="\nTimestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
HEADER+="\n========================\n"

collect() {
  printf "$HEADER"
  echo ""

  # Run JDB with scripted input, with a timeout
  if command -v timeout &>/dev/null; then
    timeout 30 jdb -attach "${HOST}:${PORT}" < "$TMPFILE" 2>&1 || true
  elif command -v gtimeout &>/dev/null; then
    gtimeout 30 jdb -attach "${HOST}:${PORT}" < "$TMPFILE" 2>&1 || true
  else
    jdb -attach "${HOST}:${PORT}" < "$TMPFILE" 2>&1 || true
  fi
}

if [[ -n "$OUTPUT" ]]; then
  collect > "$OUTPUT"
  echo "Diagnostics written to: $OUTPUT"
else
  collect
fi

# Cleanup
rm -f "$TMPFILE"
