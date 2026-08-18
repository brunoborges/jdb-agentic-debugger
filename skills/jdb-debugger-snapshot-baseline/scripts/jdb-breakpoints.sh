#!/usr/bin/env bash
# jdb-breakpoints.sh — Set breakpoints and start a JDB session (interactive or batch)
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Launch or attach JDB with breakpoints. Supports both interactive sessions
and automated batch debugging.

Breakpoint sources (use one):
  --breakpoints <file>   File containing breakpoint commands (one per line)
  --bp <command>         Inline breakpoint command (repeatable)

Batch mode (use one, requires --bp or --breakpoints):
  --auto-inspect <N>     Run N cycles of where+locals+cont, then quit
  --cmd <command>        JDB command to execute after breakpoints (repeatable)
  --timeout <seconds>    Kill JDB session after this many seconds (for hanging apps)

Connection options:
  --host <hostname>      Attach to host (default: launch mode)
  --port <port>          JDWP port for attach mode (default: 5005)
  --mainclass <class>    Main class for launch mode
  --sourcepath <path>    Source directories
  --classpath <path>     Classpath for launch mode
  -h, --help             Show this help message

Environment variables for batch timing:
  JDB_BP_DELAY    Delay after each breakpoint command (default: 2)
  JDB_RUN_DELAY   Delay after 'run' command (default: 3)
  JDB_CMD_DELAY   Delay after each --cmd command (default: 0.5)
  JDB_CONT_DELAY  Delay after 'cont' command in --auto-inspect (default: 1)

Examples:
  # Interactive with breakpoints file
  $(basename "$0") --breakpoints bp.txt --mainclass com.example.Main

  # Batch: inline breakpoints + auto-inspect
  $(basename "$0") --mainclass com.example.Main \\
    --bp "stop in com.example.Main.process" \\
    --bp "catch java.lang.NullPointerException" \\
    --auto-inspect 10

  # Batch with timeout for potentially hanging apps
  $(basename "$0") --mainclass com.example.Main \\
    --bp "catch java.lang.Exception" \\
    --auto-inspect 10 --timeout 30

  # Batch: inline breakpoints + custom commands
  $(basename "$0") --mainclass com.example.Main \\
    --bp "stop in com.example.Main.process" \\
    --cmd "run" --cmd "locals" --cmd "cont" --cmd "quit"

EOF
  exit 0
}

BREAKPOINTS_FILE=""
HOST=""
PORT="5005"
MAINCLASS=""
SOURCEPATH=""
CLASSPATH_ARG=""
AUTO_INSPECT=""
TIMEOUT=""
declare -a BP_ARGS=()
declare -a CMD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --breakpoints)
      BREAKPOINTS_FILE="$2"
      shift 2
      ;;
    --bp)
      BP_ARGS+=("$2")
      shift 2
      ;;
    --cmd)
      CMD_ARGS+=("$2")
      shift 2
      ;;
    --auto-inspect)
      AUTO_INSPECT="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
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

# Validate: need either --breakpoints or --bp
if [[ -z "$BREAKPOINTS_FILE" && ${#BP_ARGS[@]} -eq 0 ]]; then
  echo "Error: --breakpoints <file> or --bp <command> is required."
  echo ""
  usage
fi

# Validate: --breakpoints and --bp are mutually exclusive
if [[ -n "$BREAKPOINTS_FILE" && ${#BP_ARGS[@]} -gt 0 ]]; then
  echo "Error: --breakpoints and --bp are mutually exclusive. Use one or the other."
  exit 1
fi

# Validate: --auto-inspect and --cmd are mutually exclusive
if [[ -n "$AUTO_INSPECT" && ${#CMD_ARGS[@]} -gt 0 ]]; then
  echo "Error: --auto-inspect and --cmd are mutually exclusive. Use one or the other."
  exit 1
fi

# Validate breakpoints file exists if specified
if [[ -n "$BREAKPOINTS_FILE" && ! -f "$BREAKPOINTS_FILE" ]]; then
  echo "Error: Breakpoints file not found: $BREAKPOINTS_FILE"
  exit 1
fi

# Verify jdb is available
if ! command -v jdb &>/dev/null; then
  echo "Error: 'jdb' not found. Ensure the JDK is installed and on your PATH."
  exit 1
fi

# Build breakpoint commands
INIT_CMDS=""
if [[ -n "$BREAKPOINTS_FILE" ]]; then
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    INIT_CMDS+="${line}\n"
  done < "$BREAKPOINTS_FILE"
else
  for bp in "${BP_ARGS[@]}"; do
    INIT_CMDS+="${bp}\n"
  done
fi

BP_COUNT=$(echo -e "$INIT_CMDS" | grep -c -E '^(stop|catch)' || true)
echo "=== JDB Breakpoints ==="
echo "Loaded $BP_COUNT breakpoint/catch commands"
echo "========================"
echo ""

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

# Determine mode: batch (--auto-inspect or --cmd) vs interactive
IS_BATCH=false
if [[ -n "$AUTO_INSPECT" || ${#CMD_ARGS[@]} -gt 0 ]]; then
  IS_BATCH=true
fi

if [[ "$IS_BATCH" == true ]]; then
  # Batch mode: use subshell with sleep delays piped to jdb
  BP_DELAY="${JDB_BP_DELAY:-2}"
  RUN_DELAY="${JDB_RUN_DELAY:-3}"
  CMD_DELAY="${JDB_CMD_DELAY:-0.5}"
  CONT_DELAY="${JDB_CONT_DELAY:-1}"

  echo "Running in batch mode..."
  [[ -n "$TIMEOUT" ]] && echo "Timeout: ${TIMEOUT}s"
  echo ""

  run_batch() {
    (
      # Send breakpoint commands
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        echo "$line"
        sleep "$BP_DELAY"
      done < <(echo -e "$INIT_CMDS")

      if [[ -n "$AUTO_INSPECT" ]]; then
        # Auto-inspect mode: run + N cycles of where/locals/cont + quit
        echo "run"
        sleep "$RUN_DELAY"

        for ((i = 1; i <= AUTO_INSPECT; i++)); do
          echo "where"
          sleep "$CMD_DELAY"
          echo "locals"
          sleep "$CMD_DELAY"
          echo "cont"
          sleep "$CONT_DELAY"
        done

        echo "quit"
      else
        # Custom commands mode
        for cmd_arg in "${CMD_ARGS[@]}"; do
          echo "$cmd_arg"
          if [[ "$cmd_arg" == "run" ]]; then
            sleep "$RUN_DELAY"
          elif [[ "$cmd_arg" == "cont" ]]; then
            sleep "$CONT_DELAY"
          else
            sleep "$CMD_DELAY"
          fi
        done
      fi
    ) | $CMD
  }

  if [[ -n "$TIMEOUT" ]]; then
    # Run with timeout — kill the session if it exceeds the limit
    run_batch &
    BATCH_PID=$!
    (
      sleep "$TIMEOUT"
      if kill -0 "$BATCH_PID" 2>/dev/null; then
        echo ""
        echo "=== TIMEOUT: JDB session killed after ${TIMEOUT}s (app may be hanging/deadlocked) ==="
        kill -TERM "$BATCH_PID" 2>/dev/null
        sleep 2
        kill -9 "$BATCH_PID" 2>/dev/null
      fi
    ) &
    TIMER_PID=$!
    wait "$BATCH_PID" 2>/dev/null || true
    kill "$TIMER_PID" 2>/dev/null || true
    wait "$TIMER_PID" 2>/dev/null || true
  else
    run_batch
  fi

else
  # Interactive mode: feed breakpoints then hand control to terminal
  TMPFILE=$(mktemp /tmp/jdb-bp-XXXXXX.txt)
  printf "$INIT_CMDS" > "$TMPFILE"

  echo "Setting breakpoints and starting JDB..."
  echo ""

  (cat "$TMPFILE"; cat) | $CMD

  # Cleanup
  rm -f "$TMPFILE"
fi
