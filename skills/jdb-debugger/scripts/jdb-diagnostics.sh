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
      [[ $# -ge 2 ]] || { echo "Error: --host requires a value." >&2; exit 2; }
      HOST="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || { echo "Error: --port requires a value." >&2; exit 2; }
      PORT="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "Error: --output requires a value." >&2; exit 2; }
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

if [[ -z "$HOST" ]]; then
  echo "Error: --host must not be empty." >&2
  exit 2
fi
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Error: --port must be an integer from 1 to 65535." >&2
  exit 2
fi
if ! $COLLECT_THREADS && ! $COLLECT_CLASSES; then
  echo "Error: no diagnostics selected; enable --threads or --classes." >&2
  exit 2
fi

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

HEADER="=== JVM Diagnostics ==="
HEADER+="\nHost: ${HOST}:${PORT}"
HEADER+="\nTimestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
HEADER+="\n========================\n"

collect() {
  printf '%b' "$HEADER"
  echo ""

  # Run JDB with scripted input and preserve connection/timeout failures.
  if command -v timeout &>/dev/null; then
    printf '%b' "$JDB_COMMANDS" | timeout 30 jdb -attach "${HOST}:${PORT}" 2>&1
  elif command -v gtimeout &>/dev/null; then
    printf '%b' "$JDB_COMMANDS" | gtimeout 30 jdb -attach "${HOST}:${PORT}" 2>&1
  else
    printf '%b' "$JDB_COMMANDS" | jdb -attach "${HOST}:${PORT}" 2>&1
  fi
}

if [[ -n "$OUTPUT" ]]; then
  set +e
  collect > "$OUTPUT"
  status=$?
  set -e
  if (( status != 0 )); then
    echo "Error: diagnostics failed; partial output written to: $OUTPUT" >&2
    exit "$status"
  fi
  echo "Diagnostics written to: $OUTPUT"
else
  collect
fi
