#!/usr/bin/env bash
# jdb-breakpoints.sh — Set breakpoints and start a JDB session (interactive or batch)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
                         In attach mode (--host), skips 'run' and waits
                         for a breakpoint to be hit before inspecting.
  --cmd <command>        JDB command to execute after breakpoints (repeatable)
  --timeout <seconds>    Kill JDB session after this many seconds (default: 60)

Connection options:
  --host <hostname>      Attach to host (default: launch mode)
  --port <port>          JDWP port for attach mode (default: 5005)
  --mainclass <class>    Main class for launch mode
  --sourcepath <path>    Source directories
  --classpath <path>     Classpath for launch mode
  -h, --help             Show this help message

ATTACH MODE GUIDE (--host):
  In attach mode, the JVM is already running (suspend=n). Breakpoints only
  suspend the thread that hits them; other threads keep running.

  RECOMMENDED pattern — let the breakpoint hit first, then query:
    bash jdb-breakpoints.sh --host <ip> --port <port> \\
      --bp "stop in com.example.MyClass.myMethod" \\
      --cmd "where" --cmd "locals" --cmd "cont" --cmd "quit" \\
      --timeout 60

  OVERLOADED METHODS: If "stop in Class.method" fails with "already overloaded",
  the script automatically runs "methods Class" to show available signatures.
  Then re-run with the full signature:
    --bp "stop in Class.method(java.lang.String,int)"

  WHERE vs WHERE ALL in attach mode:
  - Use "where" to see the breakpoint thread's stack (always works)
  - "where all" only shows threads that are suspended; in suspend=n JVMs,
    only the breakpoint thread is suspended, so it's not much more useful.
    The script prints an explanation before running "where all" to reduce confusion.

  SINGLE CONNECTION LIMIT: JDWP allows only ONE debugger at a time.
  If another JDB session is connected, you'll see:
    "handshake failed - connection prematurally closed"
  Kill the other session first, then retry.

EOF
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
BREAKPOINTS_FILE=""
HOST=""
PORT="5005"
MAINCLASS=""
SOURCEPATH=""
CLASSPATH_ARG=""
AUTO_INSPECT=""
TIMEOUT="60"
declare -a BP_ARGS=()
declare -a CMD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --breakpoints) BREAKPOINTS_FILE="$2"; shift 2 ;;
    --bp) BP_ARGS+=("$2"); shift 2 ;;
    --cmd) CMD_ARGS+=("$2"); shift 2 ;;
    --auto-inspect) AUTO_INSPECT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --mainclass) MAINCLASS="$2"; shift 2 ;;
    --sourcepath) SOURCEPATH="$2"; shift 2 ;;
    --classpath) CLASSPATH_ARG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$BREAKPOINTS_FILE" && ${#BP_ARGS[@]} -eq 0 ]]; then
  echo "Error: --breakpoints <file> or --bp <command> is required."
  usage
fi
if [[ -n "$BREAKPOINTS_FILE" && ${#BP_ARGS[@]} -gt 0 ]]; then
  echo "Error: --breakpoints and --bp are mutually exclusive."
  exit 1
fi
if [[ -n "$AUTO_INSPECT" && ${#CMD_ARGS[@]} -gt 0 ]]; then
  echo "Error: --auto-inspect and --cmd are mutually exclusive."
  exit 1
fi
if [[ -n "$BREAKPOINTS_FILE" && ! -f "$BREAKPOINTS_FILE" ]]; then
  echo "Error: Breakpoints file not found: $BREAKPOINTS_FILE"
  exit 1
fi
if ! command -v jdb &>/dev/null; then
  echo "Error: 'jdb' not found. Ensure the JDK is installed and on your PATH."
  exit 1
fi

# ── Build breakpoint list ─────────────────────────────────────────────────────
declare -a ALL_BPS=()
if [[ -n "$BREAKPOINTS_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    ALL_BPS+=("$line")
  done < "$BREAKPOINTS_FILE"
else
  ALL_BPS=("${BP_ARGS[@]}")
fi

BP_COUNT=${#ALL_BPS[@]}
echo "=== JDB Breakpoints ==="
echo "Loaded $BP_COUNT breakpoint/catch command(s)"

# ── Detect mode ───────────────────────────────────────────────────────────────
IS_ATTACH=false
if [[ -n "$HOST" ]]; then
  IS_ATTACH=true
fi
[[ "$IS_ATTACH" == true ]] && echo "Mode: ATTACH (host=${HOST}:${PORT})" || echo "Mode: LAUNCH"
echo "========================"
echo ""

# ── Build jdb command ─────────────────────────────────────────────────────────
declare -a JDB_CMD_PARTS=()
if [[ "$IS_ATTACH" == true ]]; then
  JDB_CMD_PARTS=("jdb" "-attach" "${HOST}:${PORT}")
else
  JDB_CMD_PARTS=("jdb")
  [[ -n "$CLASSPATH_ARG" ]] && JDB_CMD_PARTS+=("-classpath" "$CLASSPATH_ARG")
  [[ -n "$SOURCEPATH" ]] && JDB_CMD_PARTS+=("-sourcepath" "$SOURCEPATH")
  [[ -n "$MAINCLASS" ]] && JDB_CMD_PARTS+=("$MAINCLASS")
fi

# ── Determine batch vs interactive ───────────────────────────────────────────
IS_BATCH=false
if [[ -n "$AUTO_INSPECT" || ${#CMD_ARGS[@]} -gt 0 ]]; then
  IS_BATCH=true
fi

# ── Build post-breakpoint commands ────────────────────────────────────────────
declare -a POST_CMDS=()
if [[ -n "$AUTO_INSPECT" ]]; then
  # In launch mode, start the VM first
  [[ "$IS_ATTACH" == false ]] && POST_CMDS+=("run")
  for ((i = 1; i <= AUTO_INSPECT; i++)); do
    POST_CMDS+=("where")
    POST_CMDS+=("locals")
    POST_CMDS+=("cont")
  done
  POST_CMDS+=("quit")
else
  POST_CMDS=("${CMD_ARGS[@]}")
fi

# ─────────────────────────────────────────────────────────────────────────────
# INTERACTIVE MODE — pipe breakpoints then hand control to user
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$IS_BATCH" == false ]]; then
  TMPFILE=$(mktemp /tmp/jdb-bp-XXXXXX.txt)
  for bp in "${ALL_BPS[@]}"; do
    echo "$bp" >> "$TMPFILE"
  done
  echo "Setting breakpoints and starting JDB (interactive)..."
  echo ""
  (cat "$TMPFILE"; cat) | "${JDB_CMD_PARTS[@]}"
  rm -f "$TMPFILE"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# BATCH MODE — event-driven via Python (preferred) or sleep-based fallback
# ─────────────────────────────────────────────────────────────────────────────
echo "Running in batch mode (event-driven)..."
echo "Timeout: ${TIMEOUT}s"
echo ""

PYTHON_DRIVER="${SCRIPT_DIR}/jdb-interactive.py"

if [[ -f "$PYTHON_DRIVER" ]] && command -v python3 &>/dev/null; then
  # ── Event-driven path ──────────────────────────────────────────────────────
  # Build config JSON
  CFG_FILE=$(mktemp /tmp/jdb-cfg-XXXXXX.json)

  # Serialize arrays to JSON
  jdb_cmd_json=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${JDB_CMD_PARTS[@]}")
  init_cmds_json=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${ALL_BPS[@]}")
  post_cmds_json=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${POST_CMDS[@]}")

  cat > "$CFG_FILE" <<JSONEOF
{
  "jdb_cmd": ${jdb_cmd_json},
  "init_cmds": ${init_cmds_json},
  "post_cmds": ${post_cmds_json},
  "timeout": ${TIMEOUT},
  "is_attach": ${IS_ATTACH}
}
JSONEOF

  python3 "$PYTHON_DRIVER" "$CFG_FILE"
  rm -f "$CFG_FILE"

else
  # ── Sleep-based fallback ───────────────────────────────────────────────────
  echo "[INFO] Python driver not found — using sleep-based timing."
  echo "       Results may be unreliable if timing is too tight."
  echo ""

  BP_DELAY="${JDB_BP_DELAY:-2}"
  RUN_DELAY="${JDB_RUN_DELAY:-3}"
  CMD_DELAY="${JDB_CMD_DELAY:-0.5}"
  CONT_DELAY="${JDB_CONT_DELAY:-1}"

  run_batch() {
    for bp in "${ALL_BPS[@]}"; do
      echo "$bp"
      sleep "$BP_DELAY"
    done
    for cmd in "${POST_CMDS[@]}"; do
      echo "$cmd"
      if [[ "$cmd" == "run" ]]; then
        sleep "$RUN_DELAY"
      elif [[ "$cmd" == "cont" ]]; then
        sleep "$CONT_DELAY"
      else
        sleep "$CMD_DELAY"
      fi
    done
  }

  run_batch | timeout "$TIMEOUT" "${JDB_CMD_PARTS[@]}" || true
fi
