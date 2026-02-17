#!/usr/bin/env bash
# jdb-breakpoints.sh — Set multiple breakpoints from a file and start a JDB session
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --breakpoints <file> [options]

Launch or attach JDB and automatically set breakpoints defined in a file.
Each line of the breakpoints file should contain a JDB stop command:

  stop at com.example.MyClass:42
  stop in com.example.MyClass.myMethod
  catch java.lang.NullPointerException

Options:
  --breakpoints <file>   File containing breakpoint commands (one per line)
  --host <hostname>      Attach to host (default: launch mode)
  --port <port>          JDWP port for attach mode (default: 5005)
  --mainclass <class>    Main class for launch mode
  --sourcepath <path>    Source directories
  --classpath <path>     Classpath for launch mode
  -h, --help             Show this help message

Examples:
  # Attach with breakpoints
  $(basename "$0") --breakpoints breakpoints.txt --port 5005

  # Launch with breakpoints
  $(basename "$0") --breakpoints breakpoints.txt --mainclass com.example.Main

EOF
  exit 0
}

BREAKPOINTS_FILE=""
HOST=""
PORT="5005"
MAINCLASS=""
SOURCEPATH=""
CLASSPATH_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --breakpoints)
      BREAKPOINTS_FILE="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --mainclass)
      MAINCLASS="$2"
      shift 2
      ;;
    --sourcepath)
      SOURCEPATH="$2"
      shift 2
      ;;
    --classpath)
      CLASSPATH_ARG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ -z "$BREAKPOINTS_FILE" ]]; then
  echo "Error: --breakpoints file is required."
  echo ""
  usage
fi

if [[ ! -f "$BREAKPOINTS_FILE" ]]; then
  echo "Error: Breakpoints file not found: $BREAKPOINTS_FILE"
  exit 1
fi

# Verify jdb is available
if ! command -v jdb &>/dev/null; then
  echo "Error: 'jdb' not found. Ensure the JDK is installed and on your PATH."
  exit 1
fi

# Read breakpoints and build initialization commands
INIT_CMDS=""
while IFS= read -r line; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  INIT_CMDS+="${line}\n"
done < "$BREAKPOINTS_FILE"

BP_COUNT=$(echo -e "$INIT_CMDS" | grep -c -E '^(stop|catch)' || true)
echo "=== JDB Breakpoints ==="
echo "Loaded $BP_COUNT breakpoint/catch commands from: $BREAKPOINTS_FILE"
echo "========================"
echo ""

# Create temp file for JDB input (breakpoints first, then interactive)
TMPFILE=$(mktemp /tmp/jdb-bp-XXXXXX.txt)
printf "$INIT_CMDS" > "$TMPFILE"

# Build jdb command
if [[ -n "$HOST" || -z "$MAINCLASS" ]]; then
  # Attach mode
  TARGET_HOST="${HOST:-localhost}"
  CMD="jdb -attach ${TARGET_HOST}:${PORT}"
else
  # Launch mode
  CMD="jdb"
  [[ -n "$CLASSPATH_ARG" ]] && CMD="$CMD -classpath ${CLASSPATH_ARG}"
  CMD="$CMD $MAINCLASS"
fi

[[ -n "$SOURCEPATH" ]] && CMD="$CMD -sourcepath ${SOURCEPATH}"

echo "Setting breakpoints and starting JDB..."
echo ""

# Feed breakpoints then hand control to the terminal
(cat "$TMPFILE"; cat) | $CMD

# Cleanup
rm -f "$TMPFILE"
