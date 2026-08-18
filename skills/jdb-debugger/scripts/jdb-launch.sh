#!/usr/bin/env bash
# jdb-launch.sh — Launch a Java application under JDB for debugging
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <mainclass> [options]

Launch a Java application under JDB for interactive debugging.

Arguments:
  mainclass              Fully qualified main class (e.g., com.example.Main)

Options:
  --sourcepath <path>    Colon-separated source directories (default: src/main/java)
  --classpath <path>     Colon-separated classpath (default: . or target/classes if exists)
  --jdb-args <args>      Additional arguments passed to jdb
  --app-args <args>      Arguments passed to the application's main method
  --suspend              Pause before executing main class (default: yes)
  --no-suspend           Do not pause before executing main class
  -h, --help             Show this help message

Examples:
  $(basename "$0") com.example.Main
  $(basename "$0") com.example.Main --sourcepath src/main/java:src/test/java
  $(basename "$0") com.example.Main --classpath target/classes:lib/* --app-args "arg1 arg2"

EOF
  exit 0
}

MAINCLASS=""
SOURCEPATH=""
CLASSPATH_ARG=""
JDB_ARGS=""
APP_ARGS=""
declare -a POSITIONAL_APP_ARGS=()
SUSPEND="y"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
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
    --jdb-args)
      [[ $# -ge 2 ]] || { echo "Error: --jdb-args requires a value." >&2; exit 2; }
      JDB_ARGS="$2"
      shift 2
      ;;
    --app-args)
      [[ $# -ge 2 ]] || { echo "Error: --app-args requires a value." >&2; exit 2; }
      APP_ARGS="$2"
      read -r -a EXTRA_APP_ARGS <<< "$2"
      POSITIONAL_APP_ARGS+=("${EXTRA_APP_ARGS[@]}")
      shift 2
      ;;
    --suspend)
      SUSPEND="y"
      shift
      ;;
    --no-suspend)
      SUSPEND="n"
      shift
      ;;
    *)
      if [[ -z "$MAINCLASS" ]]; then
        if [[ "$1" == -* ]]; then
          echo "Error: Unknown option: $1" >&2
          exit 2
        fi
        MAINCLASS="$1"
      else
        APP_ARGS="${APP_ARGS:+$APP_ARGS }$1"
        POSITIONAL_APP_ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

if [[ -z "$MAINCLASS" ]]; then
  echo "Error: Main class is required."
  echo ""
  usage
fi

# Auto-detect sourcepath
if [[ -z "$SOURCEPATH" ]]; then
  if [[ -d "src/main/java" ]]; then
    SOURCEPATH="src/main/java"
    [[ -d "src/test/java" ]] && SOURCEPATH="$SOURCEPATH:src/test/java"
  else
    SOURCEPATH="."
  fi
fi

# Auto-detect classpath
if [[ -z "$CLASSPATH_ARG" ]]; then
  if [[ -d "target/classes" ]]; then
    CLASSPATH_ARG="target/classes"
    [[ -d "target/test-classes" ]] && CLASSPATH_ARG="$CLASSPATH_ARG:target/test-classes"
    [[ -d "target/dependency" ]] && CLASSPATH_ARG="$CLASSPATH_ARG:target/dependency/*"
  elif [[ -d "build/classes" ]]; then
    CLASSPATH_ARG="build/classes/java/main"
    [[ -d "build/classes/java/test" ]] && CLASSPATH_ARG="$CLASSPATH_ARG:build/classes/java/test"
  else
    CLASSPATH_ARG="."
  fi
fi

# Verify jdb is available
if ! command -v jdb &>/dev/null; then
  echo "Error: 'jdb' not found. Ensure the JDK is installed and on your PATH."
  echo "  Try: export PATH=\$JAVA_HOME/bin:\$PATH"
  exit 1
fi

echo "=== JDB Launch ==="
echo "Main class:  $MAINCLASS"
echo "Source path: $SOURCEPATH"
echo "Classpath:   $CLASSPATH_ARG"
echo "Suspend:     $SUSPEND"
[[ -n "$APP_ARGS" ]] && echo "App args:    $APP_ARGS"
echo "=================="
echo ""
echo "Tip: Type 'stop in ${MAINCLASS}.main' then 'run' to start debugging."
echo ""

# Build an argument-safe command. The legacy aggregate argument options are
# whitespace-delimited; callers needing embedded spaces should pass arguments
# positionally after the main class.
CMD=(jdb -sourcepath "$SOURCEPATH" -classpath "$CLASSPATH_ARG")
if [[ -n "$JDB_ARGS" ]]; then
  read -r -a EXTRA_JDB_ARGS <<< "$JDB_ARGS"
  CMD+=("${EXTRA_JDB_ARGS[@]}")
fi
CMD+=("$MAINCLASS")
if [[ -n "$APP_ARGS" ]]; then
  CMD+=("${POSITIONAL_APP_ARGS[@]}")
fi

exec "${CMD[@]}"
