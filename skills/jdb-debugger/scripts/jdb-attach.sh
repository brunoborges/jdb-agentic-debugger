#!/usr/bin/env bash
# jdb-attach.sh — Attach JDB to a running JVM with JDWP enabled
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Attach JDB to a running JVM that has the JDWP agent enabled.

Options:
  --host <hostname>      Target host (default: localhost)
  --port <port>          JDWP port (default: 5005)
  --sourcepath <path>    Colon-separated source directories
  --jdb-args <args>      Additional arguments passed to jdb
  -h, --help             Show this help message

Prerequisites:
  The target JVM must have been started with JDWP enabled:
    java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 ...

Examples:
  $(basename "$0")                                    # localhost:5005
  $(basename "$0") --port 8000                        # localhost:8000
  $(basename "$0") --host 10.0.1.5 --port 5005        # remote host
  $(basename "$0") --sourcepath src/main/java          # with source

EOF
  exit 0
}

HOST="localhost"
PORT="5005"
SOURCEPATH=""
JDB_ARGS=""

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
    --sourcepath)
      [[ $# -ge 2 ]] || { echo "Error: --sourcepath requires a value." >&2; exit 2; }
      SOURCEPATH="$2"
      shift 2
      ;;
    --jdb-args)
      [[ $# -ge 2 ]] || { echo "Error: --jdb-args requires a value." >&2; exit 2; }
      JDB_ARGS="$2"
      shift 2
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

# Verify jdb is available
if ! command -v jdb &>/dev/null; then
  echo "Error: 'jdb' not found. Ensure the JDK is installed and on your PATH."
  echo "  Try: export PATH=\$JAVA_HOME/bin:\$PATH"
  exit 1
fi

# Auto-detect sourcepath
if [[ -z "$SOURCEPATH" ]]; then
  if [[ -d "src/main/java" ]]; then
    SOURCEPATH="src/main/java"
    [[ -d "src/test/java" ]] && SOURCEPATH="$SOURCEPATH:src/test/java"
  fi
fi

# Check if port is reachable (quick test)
if command -v nc &>/dev/null; then
  if ! nc -z "$HOST" "$PORT" 2>/dev/null; then
    echo "Warning: Cannot reach ${HOST}:${PORT}. The JVM may not be running or JDWP may not be enabled."
    echo ""
    echo "Ensure the target JVM was started with:"
    echo "  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${PORT} ..."
    echo ""
    echo "Attempting to connect anyway..."
    echo ""
  fi
fi

echo "=== JDB Attach ==="
echo "Target: ${HOST}:${PORT}"
[[ -n "$SOURCEPATH" ]] && echo "Source path: $SOURCEPATH"
echo "==================="
echo ""

# Build an argument-safe command.
CMD=(jdb -attach "${HOST}:${PORT}")
[[ -n "$SOURCEPATH" ]] && CMD+=(-sourcepath "$SOURCEPATH")
if [[ -n "$JDB_ARGS" ]]; then
  read -r -a EXTRA_JDB_ARGS <<< "$JDB_ARGS"
  CMD+=("${EXTRA_JDB_ARGS[@]}")
fi

exec "${CMD[@]}"
