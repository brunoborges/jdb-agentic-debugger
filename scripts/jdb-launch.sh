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
SUSPEND="y"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --sourcepath)
      SOURCEPATH="$2"
      shift 2
      ;;
    --classpath)
      CLASSPATH_ARG="$2"
      shift 2
      ;;
    --jdb-args)
      JDB_ARGS="$2"
      shift 2
      ;;
    --app-args)
      APP_ARGS="$2"
      shift 2
      ;;
    --no-suspend)
      SUSPEND="n"
      shift
      ;;
    *)
      if [[ -z "$MAINCLASS" ]]; then
        MAINCLASS="$1"
      else
        APP_ARGS="${APP_ARGS:+$APP_ARGS }$1"
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

# Build jdb command
CMD="jdb -sourcepath ${SOURCEPATH} -classpath ${CLASSPATH_ARG}"
[[ -n "$JDB_ARGS" ]] && CMD="$CMD $JDB_ARGS"
CMD="$CMD $MAINCLASS"
[[ -n "$APP_ARGS" ]] && CMD="$CMD $APP_ARGS"

exec $CMD
