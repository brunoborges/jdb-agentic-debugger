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
      [[ $# -ge 2 ]] || { echo "Error: --breakpoints requires a value." >&2; exit 2; }
      BREAKPOINTS_FILE="$2"
      shift 2
      ;;
    --bp)
      [[ $# -ge 2 ]] || { echo "Error: --bp requires a value." >&2; exit 2; }
      BP_ARGS+=("$2")
      shift 2
      ;;
    --cmd)
      [[ $# -ge 2 ]] || { echo "Error: --cmd requires a value." >&2; exit 2; }
      CMD_ARGS+=("$2")
      shift 2
      ;;
    --auto-inspect)
      [[ $# -ge 2 ]] || { echo "Error: --auto-inspect requires a value." >&2; exit 2; }
      AUTO_INSPECT="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || { echo "Error: --timeout requires a value." >&2; exit 2; }
      TIMEOUT="$2"
      shift 2
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
    --mainclass)
      [[ $# -ge 2 ]] || { echo "Error: --mainclass requires a value." >&2; exit 2; }
      MAINCLASS="$2"
      shift 2
      ;;
    --sourcepath)
      [[ $# -ge 2 ]] || { echo "Error: --sourcepath requires a value." >&2; exit 2; }
      SOURCEPATH="$2"
      shift 2
      ;;
    --classpath)
      [[ $# -ge 2 ]] || { echo "Error: --classpath requires a value." >&2; exit 2; }
      CLASSPATH_ARG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Error: --port must be an integer from 1 to 65535." >&2
  exit 2
fi
if [[ -n "$AUTO_INSPECT" ]] && { [[ ! "$AUTO_INSPECT" =~ ^[0-9]+$ ]] || (( AUTO_INSPECT < 1 )); }; then
  echo "Error: --auto-inspect must be a positive integer." >&2
  exit 2
fi
if [[ -n "$TIMEOUT" ]] && { [[ ! "$TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ "$TIMEOUT" == 0 || "$TIMEOUT" == 0.0 ]]; }; then
  echo "Error: --timeout must be a positive number." >&2
  exit 2
fi

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

# Build an argument-safe jdb command.
if [[ -n "$HOST" || -z "$MAINCLASS" ]]; then
  # Attach mode
  TARGET_HOST="${HOST:-localhost}"
  CMD=(jdb -attach "${TARGET_HOST}:${PORT}")
else
  # Launch mode
  CMD=(jdb)
  [[ -n "$CLASSPATH_ARG" ]] && CMD+=(-classpath "$CLASSPATH_ARG")
  CMD+=("$MAINCLASS")
fi

[[ -n "$SOURCEPATH" ]] && CMD+=(-sourcepath "$SOURCEPATH")

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
    ) | "${CMD[@]}"
  }

  if [[ -n "$TIMEOUT" ]]; then
    # Run with timeout — kill the session if it exceeds the limit
    TIMEOUT_MARKER=$(mktemp "${TMPDIR:-/tmp}/jdb-timeout-XXXXXX")
    rm -f "$TIMEOUT_MARKER"
    trap 'rm -f "$TIMEOUT_MARKER"' EXIT HUP INT TERM
    if command -v setsid &>/dev/null; then
      run_batch_with_group() {
        (
          while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            echo "$line"
            sleep "$BP_DELAY"
          done < <(printf '%b' "$INIT_CMDS")
          if [[ -n "$AUTO_INSPECT" ]]; then
            echo run; sleep "$RUN_DELAY"
            for ((i = 1; i <= AUTO_INSPECT; i++)); do
              echo where; sleep "$CMD_DELAY"
              echo locals; sleep "$CMD_DELAY"
              echo cont; sleep "$CONT_DELAY"
            done
            echo quit
          else
            for cmd_arg in "${CMD_ARGS[@]}"; do
              echo "$cmd_arg"
              if [[ "$cmd_arg" == run ]]; then sleep "$RUN_DELAY"
              elif [[ "$cmd_arg" == cont ]]; then sleep "$CONT_DELAY"
              else sleep "$CMD_DELAY"; fi
            done
          fi
        ) | setsid "${CMD[@]}"
      }
      run_batch_with_group &
    else
      run_batch &
    fi
    BATCH_PID=$!
    (
      trap - EXIT
      sleep "$TIMEOUT"
      if kill -0 "$BATCH_PID" 2>/dev/null; then
        : > "$TIMEOUT_MARKER"
        echo ""
        echo "=== TIMEOUT: JDB session killed after ${TIMEOUT}s (app may be hanging/deadlocked) ==="
        kill -TERM -- "-$BATCH_PID" 2>/dev/null || kill -TERM "$BATCH_PID" 2>/dev/null
        sleep 2
        kill -KILL -- "-$BATCH_PID" 2>/dev/null || kill -KILL "$BATCH_PID" 2>/dev/null
      fi
    ) &
    TIMER_PID=$!
    set +e
    wait "$BATCH_PID" 2>/dev/null
    BATCH_STATUS=$?
    set -e
    kill "$TIMER_PID" 2>/dev/null || true
    wait "$TIMER_PID" 2>/dev/null || true
    if [[ -f "$TIMEOUT_MARKER" ]]; then
      rm -f "$TIMEOUT_MARKER"
      trap - EXIT HUP INT TERM
      exit 124
    fi
    rm -f "$TIMEOUT_MARKER"
    trap - EXIT HUP INT TERM
    exit "$BATCH_STATUS"
  else
    run_batch
  fi

else
  # Interactive mode: feed breakpoints then hand control to terminal
  TMPFILE=$(mktemp "${TMPDIR:-/tmp}/jdb-bp-XXXXXX.txt")
  trap 'rm -f "$TMPFILE"' EXIT HUP INT TERM
  printf '%b' "$INIT_CMDS" > "$TMPFILE"

  echo "Setting breakpoints and starting JDB..."
  echo ""

  (cat "$TMPFILE"; cat) | "${CMD[@]}"

  # Cleanup
  rm -f "$TMPFILE"
  trap - EXIT HUP INT TERM
fi
