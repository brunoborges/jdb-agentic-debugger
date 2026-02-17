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
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --sourcepath)
      SOURCEPATH="$2"
      shift 2
      ;;
    --jdb-args)
      JDB_ARGS="$2"
      shift 2
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

# Build jdb command
CMD="jdb -attach ${HOST}:${PORT}"
[[ -n "$SOURCEPATH" ]] && CMD="$CMD -sourcepath ${SOURCEPATH}"
[[ -n "$JDB_ARGS" ]] && CMD="$CMD $JDB_ARGS"

exec $CMD
