#!/usr/bin/env bash
# Deterministic tests for scripts and repository metadata.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$REPO_ROOT/skills/jdb-debugger/scripts"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/jdb-unit-XXXXXX")
FIXTURE_PID=""
trap '[[ -z "$FIXTURE_PID" ]] || kill "$FIXTURE_PID" 2>/dev/null || true; rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

passed=0
failed=0

pass() { echo "ok - $1"; passed=$((passed + 1)); }
fail() { echo "not ok - $1" >&2; failed=$((failed + 1)); }

run_test() {
  local name="$1"
  shift
  if "$@"; then pass "$name"; else fail "$name"; fi
}

expect_status() {
  local expected="$1"
  shift
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  [[ "$actual" -eq "$expected" ]]
}

test_help() {
  local script
  for script in "$SCRIPTS"/*.sh; do
    "$script" --help | grep -q '^Usage:'
  done
}

test_validation() {
  expect_status 2 "$SCRIPTS/jdb-attach.sh" --port nope &&
    expect_status 2 "$SCRIPTS/jdb-diagnostics.sh" --port 70000 &&
    expect_status 2 "$SCRIPTS/jdb-breakpoints.sh" --bp catch --auto-inspect 0 &&
    expect_status 2 "$SCRIPTS/jdb-launch.sh" Main --classpath
}

make_fake_jdb() {
  mkdir -p "$TMP_ROOT/bin"
  cat > "$TMP_ROOT/bin/jdb" <<'EOF'
#!/usr/bin/env bash
printf '<%s>\n' "$@"
cat >/dev/null || true
exit "${FAKE_JDB_STATUS:-0}"
EOF
  chmod +x "$TMP_ROOT/bin/jdb"
}

test_argument_safety() {
  make_fake_jdb
  local output
  output=$(PATH="$TMP_ROOT/bin:$PATH" "$SCRIPTS/jdb-launch.sh" Example \
    --sourcepath "$TMP_ROOT/source path" --classpath "$TMP_ROOT/class path" \
    --app-args "legacy arguments" "hello world")
  grep -Fq "<$TMP_ROOT/source path>" <<< "$output" &&
    grep -Fq "<$TMP_ROOT/class path>" <<< "$output" &&
    grep -Fq '<Example>' <<< "$output" &&
    grep -Fq '<legacy>' <<< "$output" &&
    grep -Fq '<arguments>' <<< "$output" &&
    grep -Fq '<hello world>' <<< "$output"
}

test_attach_arguments() {
  make_fake_jdb
  local output
  output=$(PATH="$TMP_ROOT/bin:$PATH" "$SCRIPTS/jdb-attach.sh" \
    --host localhost --port 5005 --sourcepath "$TMP_ROOT/source path")
  grep -Fq '<localhost:5005>' <<< "$output" &&
    grep -Fq "<$TMP_ROOT/source path>" <<< "$output"
}

test_diagnostics_status() {
  make_fake_jdb
  expect_status 7 env PATH="$TMP_ROOT/bin:$PATH" FAKE_JDB_STATUS=7 \
    "$SCRIPTS/jdb-diagnostics.sh" --port 5005
}

test_breakpoint_batch() {
  make_fake_jdb
  local output
  output=$(PATH="$TMP_ROOT/bin:$PATH" JDB_BP_DELAY=0 JDB_RUN_DELAY=0 \
    JDB_CMD_DELAY=0 JDB_CONT_DELAY=0 "$SCRIPTS/jdb-breakpoints.sh" \
    --mainclass Example --classpath "$TMP_ROOT/class path" \
    --bp "catch java.lang.Exception" --auto-inspect 1)
  grep -Fq "<$TMP_ROOT/class path>" <<< "$output" && grep -Fq '<Example>' <<< "$output"
}

test_timeout_status_and_cleanup() {
  mkdir -p "$TMP_ROOT/slow-bin" "$TMP_ROOT/temp"
  cat > "$TMP_ROOT/slow-bin/jdb" <<'EOF'
#!/usr/bin/env bash
trap 'exit 143' TERM
echo "$$" > "$FAKE_JDB_PID_FILE"
sleep 10
EOF
  chmod +x "$TMP_ROOT/slow-bin/jdb"
  expect_status 124 env PATH="$TMP_ROOT/slow-bin:$PATH" TMPDIR="$TMP_ROOT/temp" \
    FAKE_JDB_PID_FILE="$TMP_ROOT/fake-jdb.pid" \
    JDB_BP_DELAY=0 JDB_RUN_DELAY=0 JDB_CMD_DELAY=0 JDB_CONT_DELAY=0 \
    "$SCRIPTS/jdb-breakpoints.sh" --mainclass Example --bp "catch java.lang.Exception" \
    --auto-inspect 1 --timeout 0.2 &&
    ! find "$TMP_ROOT/temp" -type f -name 'jdb-*' | grep -q . &&
    [[ -s "$TMP_ROOT/fake-jdb.pid" ]] &&
    ! kill -0 "$(cat "$TMP_ROOT/fake-jdb.pid")" 2>/dev/null
}

start_jdwp_fixture() {
  local main_class="$1"
  local classpath="$2"
  local log_file="$3"
  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=127.0.0.1:0 \
    -cp "$classpath" "$main_class" >"$log_file" 2>&1 &
  FIXTURE_PID=$!
  FIXTURE_PORT=""
  for _ in {1..50}; do
    FIXTURE_PORT=$(sed -n 's/.*address: \([0-9][0-9]*\).*/\1/p' "$log_file" | head -1)
    [[ -n "$FIXTURE_PORT" ]] && return 0
    kill -0 "$FIXTURE_PID" 2>/dev/null || return 1
    sleep 0.1
  done
  return 1
}

stop_jdwp_fixture() {
  [[ -n "${FIXTURE_PID:-}" ]] || return 0
  kill "$FIXTURE_PID" 2>/dev/null || true
  wait "$FIXTURE_PID" 2>/dev/null || true
  FIXTURE_PID=""
}

test_local_jdwp_diagnostics() {
  local classes="$TMP_ROOT/jdwp classes"
  mkdir -p "$classes"
  javac --release 17 -g -d "$classes" "$REPO_ROOT/tests/scenarios/ThreadTest.java"
  start_jdwp_fixture ThreadTest "$classes" "$TMP_ROOT/thread-fixture.log" || {
    stop_jdwp_fixture
    return 1
  }
  sleep 1
  local output status
  set +e
  output=$("$SCRIPTS/jdb-diagnostics.sh" --host 127.0.0.1 --port "$FIXTURE_PORT" 2>&1)
  status=$?
  set -e
  stop_jdwp_fixture
  [[ "$status" -eq 0 ]] &&
    grep -q 'test-t1' <<< "$output" &&
    grep -q 'test-t2' <<< "$output"
}

test_exception_debugging() {
  local classes="$TMP_ROOT/exception classes"
  mkdir -p "$classes"
  cat > "$TMP_ROOT/ExceptionFixture.java" <<'EOF'
public class ExceptionFixture {
    public static void main(String[] args) {
        throw new IllegalStateException("fixture");
    }
}
EOF
  javac --release 17 -g -d "$classes" "$TMP_ROOT/ExceptionFixture.java"
  local output
  output=$(JDB_BP_DELAY=0.2 JDB_RUN_DELAY=1 JDB_CMD_DELAY=0.2 JDB_CONT_DELAY=0.2 \
    "$SCRIPTS/jdb-breakpoints.sh" --mainclass ExceptionFixture \
    --classpath "$classes" --bp "catch java.lang.IllegalStateException" \
    --auto-inspect 1 --timeout 10 2>&1)
  grep -q 'IllegalStateException' <<< "$output" &&
    grep -q 'ExceptionFixture.main' <<< "$output"
}

test_metadata() {
  python3 "$REPO_ROOT/tests/validate-repository.py"
}

run_test "all scripts expose help" test_help
run_test "invalid arguments fail clearly" test_validation
run_test "launch preserves path arguments" test_argument_safety
run_test "attach preserves path arguments" test_attach_arguments
run_test "diagnostics preserves jdb failure" test_diagnostics_status
run_test "breakpoint batch preserves arguments" test_breakpoint_batch
run_test "timeout returns 124 and cleans files" test_timeout_status_and_cleanup
run_test "local JDWP diagnostics capture deadlocked threads" test_local_jdwp_diagnostics
run_test "exception fixture is debugged from a spaced path" test_exception_debugging
run_test "repository metadata is consistent" test_metadata

echo "1..$((passed + failed))"
echo "# passed: $passed; failed: $failed"
(( failed == 0 ))
