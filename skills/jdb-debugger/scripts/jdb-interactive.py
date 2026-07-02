#!/usr/bin/env python3
"""
jdb-interactive.py — Event-driven JDB session driver.

This script replaces sleep-based batch timing with true event-driven execution:
it reads JDB output line by line and only proceeds to the next command once
the expected output pattern appears.

Usage (called by jdb-breakpoints.sh):
  python3 jdb-interactive.py <json-config-file>

Config JSON format:
  {
    "jdb_cmd": ["jdb", "-attach", "localhost:15005"],
    "init_cmds": ["stop in AttachDemo.handleRequest"],
    "post_cmds": ["where", "locals", "cont", "quit"],
    "timeout": 60,
    "is_attach": true,
    "auto_inspect": 0
  }
"""

import json
import os
import re
import select
import subprocess
import sys
import time
import threading

# ── Patterns ──────────────────────────────────────────────────────────────────

# JDB is ready for input — matches prompts like "> ", "main[1] ", etc.
PROMPT_PAT = re.compile(r'(?:^|\n)\s*(?:>|\w+\[\d+\])\s*$')

# Breakpoint confirmation (Chinese or English JDB output)
# NOTE: Must NOT match "无法设置断点" (failed to set breakpoint)
BP_SET_PAT = re.compile(r'(?<!无法)(设置断点|Breakpoint set|正在延迟断点|Deferring breakpoint|设置延迟的未捕获)')

# Overloaded method error
BP_OVERLOAD_PAT = re.compile(r'(已重载方法|already overloaded|请指定参数)')

# Breakpoint was hit
BP_HIT_PAT = re.compile(r'(断点命中|Breakpoint hit)')

# JDB initialized — also matches the first prompt ">"
JDB_INIT_PAT = re.compile(r'(正在初始化jdb|Initializing jdb|\> \s*$|> $)')

# Stack frame line (e.g. "[1] AttachDemo.handleRequest ...")
STACK_FRAME_PAT = re.compile(r'\s+\[\d+\]')

# Thread not suspended warning
NOT_SUSPENDED_PAT = re.compile(r'(未指定线程|No current thread|当前线程未挂起|Current thread not suspended)')

# ── Helper ────────────────────────────────────────────────────────────────────

class JDBSession:
    def __init__(self, cmd, timeout=60):
        self.timeout = timeout
        env = os.environ.copy()
        # Force UTF-8 output so we can match Chinese or English JDB strings
        env.setdefault('JAVA_TOOL_OPTIONS', '-Dfile.encoding=UTF-8')
        env['JAVA_TOOL_OPTIONS'] = re.sub(
            r'-Dfile\.encoding=\S+', '-Dfile.encoding=UTF-8',
            env.get('JAVA_TOOL_OPTIONS', '')
        ) or '-Dfile.encoding=UTF-8'
        self.proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            bufsize=0,
            env=env,
        )
        self._output_buf = []
        self._done = False
        self._lock = threading.Lock()
        # Start reader thread
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    def _read_loop(self):
        """Continuously reads JDB output into buffer, handling multi-byte UTF-8."""
        raw_buf = b''
        try:
            while True:
                chunk = self.proc.stdout.read(64)
                if not chunk:
                    break
                raw_buf += chunk
                # Decode as much valid UTF-8 as possible; keep incomplete bytes
                text, raw_buf = self._decode_partial(raw_buf)
                if text:
                    with self._lock:
                        self._output_buf.append(text)
        except Exception:
            pass
        # Decode any remaining bytes
        if raw_buf:
            with self._lock:
                self._output_buf.append(raw_buf.decode('utf-8', errors='replace'))
        self._done = True

    @staticmethod
    def _decode_partial(raw: bytes):
        """Decode as much of raw as is valid UTF-8; return (decoded_str, leftover_bytes)."""
        # Try decoding all at once
        try:
            return raw.decode('utf-8'), b''
        except UnicodeDecodeError as e:
            # e.start is the position of the first bad byte
            good = raw[:e.start].decode('utf-8', errors='replace')
            rest = raw[e.start:]
            # If the remaining bytes look like the start of a multi-byte sequence,
            # keep them for the next chunk. Otherwise discard.
            if len(rest) < 4:
                return good, rest  # wait for more bytes
            return good + rest.decode('utf-8', errors='replace'), b''

    def drain(self):
        """Return and clear all buffered output."""
        with self._lock:
            data = ''.join(self._output_buf)
            self._output_buf.clear()
        return data

    def send(self, cmd):
        """Send a command to JDB stdin."""
        line = cmd.strip() + '\n'
        try:
            self.proc.stdin.write(line.encode())
            self.proc.stdin.flush()
        except BrokenPipeError:
            pass

    def wait_for(self, patterns, timeout=None, accumulate_lines=None):
        """
        Wait until one of the given regex patterns appears in output.
        Returns (matched_pattern_index, accumulated_output).
        Returns (-1, output) on timeout.
        """
        if timeout is None:
            timeout = self.timeout
        deadline = time.time() + timeout
        accumulated = ''
        while time.time() < deadline:
            chunk = self.drain()
            if chunk:
                accumulated += chunk
                sys.stdout.write(chunk)
                sys.stdout.flush()
                for i, pat in enumerate(patterns):
                    if pat.search(accumulated):
                        return i, accumulated
            if self._done:
                break
            time.sleep(0.05)
        return -1, accumulated

    def wait_for_prompt(self, timeout=None):
        """Wait until JDB shows a command prompt."""
        return self.wait_for([PROMPT_PAT], timeout=timeout)

    def close(self):
        try:
            self.proc.stdin.close()
        except Exception:
            pass
        try:
            self.proc.terminate()
        except Exception:
            pass


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: jdb-interactive.py <config.json>")
        sys.exit(1)

    with open(sys.argv[1]) as f:
        cfg = json.load(f)

    jdb_cmd = cfg['jdb_cmd']
    init_cmds = cfg.get('init_cmds', [])
    post_cmds = cfg.get('post_cmds', [])
    timeout = cfg.get('timeout', 60)
    is_attach = cfg.get('is_attach', False)

    print(f"spawn: {' '.join(jdb_cmd)}", flush=True)

    sess = JDBSession(jdb_cmd, timeout=timeout)

    # ── Wait for JDB to initialize ────────────────────────────────────────────
    # Wait for either the Chinese/English init banner OR the first "> " prompt
    idx, out = sess.wait_for(
        [JDB_INIT_PAT, re.compile(r'> ')],
        timeout=15
    )
    if idx < 0:
        print("[ERROR] JDB did not initialize within 15s. Check connection.", flush=True)
        print("[HINT] Verify the JDWP port is open: nc -z <host> <port>", flush=True)
        print("[HINT] Only one JDB session can connect at a time (JDWP single-connection limit).", flush=True)
        sess.close()
        sys.exit(1)

    # Small settling delay to let JDB finish printing its banner
    time.sleep(0.2)
    sess.drain()

    # ── Send init (breakpoint) commands ───────────────────────────────────────
    for bp_cmd in init_cmds:
        print(f"\nsend> {bp_cmd}", flush=True)
        sess.send(bp_cmd)

        # Wait for overload error OR confirmation
        # IMPORTANT: Check OVERLOAD first (idx=0) because "无法设置断点..." contains "设置断点"
        # which would match BP_SET_PAT if checked first — giving a false-positive "success".
        idx, out = sess.wait_for(
            [BP_OVERLOAD_PAT, BP_SET_PAT],
            timeout=8
        )

        if idx == 0:  # Overload error
            # Extract class name from the command
            m = re.match(r'stop in ([A-Za-z0-9_.$]+)\.([A-Za-z0-9_$]+)', bp_cmd)
            class_name = m.group(1) if m else 'UnknownClass'
            method_name = m.group(2) if m else 'unknownMethod'

            print(f"\n[WARN] Overloaded method detected for '{bp_cmd}'", flush=True)
            print(f"  Fetching available signatures with 'methods {class_name}'...", flush=True)

            sess.send(f"methods {class_name}")
            _, methods_out = sess.wait_for_prompt(timeout=5)

            # Extract method signatures from output.
            # JDB `methods` output format: "ClassName methodName(args)" (space, not dot)
            sig_lines = []
            # Extract just the simple class name (after last dot) for matching
            simple_class = class_name.split('.')[-1]
            for line in methods_out.splitlines():
                stripped = line.strip()
                # Match lines like "AttachDemo process(java.lang.String)"
                if (simple_class in stripped or class_name in stripped) and method_name in stripped:
                    sig_lines.append(stripped)

            print(f"\n[HINT] Available overloads for '{method_name}':", flush=True)
            if sig_lines:
                for sig in sig_lines:
                    # Convert "ClassName methodName(args)" -> "ClassName.methodName(args)"
                    converted = re.sub(
                        rf'^({re.escape(simple_class)})\s+({re.escape(method_name)})',
                        r'\1.\2', sig
                    )
                    print(f"  {converted}", flush=True)
                print(f"\n[HINT] Re-run with the full signature, e.g.:", flush=True)
                # Show the first overload as example
                example = re.sub(
                    rf'^({re.escape(simple_class)})\s+({re.escape(method_name)})',
                    r'\1.\2', sig_lines[0]
                )
                print(f"  --bp \"stop in {example}\"", flush=True)
            else:
                print(f"  (Could not extract signatures — see 'methods {class_name}' output above)", flush=True)
                print(f"[HINT] Re-run with the full signature, e.g.:", flush=True)
                print(f"  --bp \"stop in {class_name}.{method_name}(java.lang.String)\"", flush=True)

            sess.send("quit")
            sess.wait_for([re.compile(r'.')], timeout=3)
            sess.close()
            sys.exit(1)

        elif idx < 0:
            print(f"[WARN] Timeout waiting for breakpoint confirmation for: {bp_cmd}", flush=True)
        # else: breakpoint set ok

    # ── In attach mode: wait for breakpoint to fire ───────────────────────────
    if is_attach:
        print("\n[INFO] Attach mode: waiting for breakpoint to be hit...", flush=True)
        print("[INFO] Trigger the action in the target JVM now.", flush=True)

        idx, out = sess.wait_for([BP_HIT_PAT], timeout=timeout)
        if idx < 0:
            print(f"[WARN] Timeout ({timeout}s): no breakpoint was hit.", flush=True)
            print("[HINT] Try increasing --timeout or trigger the action in the target app.", flush=True)
            sess.send("quit")
            sess.close()
            sys.exit(0)
    else:
        # Launch mode: wait for prompt after breakpoints are set
        sess.wait_for_prompt(timeout=5)

    # ── Execute post-breakpoint commands ──────────────────────────────────────
    for cmd in post_cmds:

        # Special handling BEFORE sending: intercept commands that need transformation
        if cmd == 'where all' and is_attach:
            # 'where all' only shows suspended threads. In suspend=n JVMs, only the
            # breakpoint thread is suspended. Send 'where all' as requested (it still
            # shows all threads we can see), but add an explanatory note.
            print(f"\n[INFO] 'where all' in suspend=n mode: only the breakpoint thread has a full", flush=True)
            print(f"       stack. Other threads show 'current thread not suspended' or are empty.", flush=True)
            print(f"       Use 'where' (without 'all') to reliably see the breakpoint thread's stack.", flush=True)
            print(f"\nsend> {cmd}", flush=True)
            sess.send(cmd)
            sess.wait_for([STACK_FRAME_PAT, PROMPT_PAT], timeout=8)
            continue

        if cmd == 'run' and is_attach:
            # In attach mode, the JVM is already running — 'run' would try to start
            # a new process which doesn't make sense in attach mode.
            print(f"\n[INFO] Skipping 'run' in attach mode (JVM is already running).", flush=True)
            continue

        print(f"\nsend> {cmd}", flush=True)
        sess.send(cmd)

        if cmd == 'quit':
            sess.wait_for([re.compile(r'.')], timeout=3)
            break
        elif cmd == 'cont':
            # After cont: wait for next breakpoint hit or prompt.
            # Key insight: in event-driven mode, we WAIT for the next hit rather than
            # timing out immediately. This means where/locals AFTER cont will see the
            # next breakpoint state correctly.
            idx, out = sess.wait_for([BP_HIT_PAT, PROMPT_PAT], timeout=timeout)
            # Continue processing — if breakpoint hit, subsequent where/locals will work
        elif cmd == 'where':
            idx, out = sess.wait_for([STACK_FRAME_PAT, NOT_SUSPENDED_PAT, PROMPT_PAT], timeout=8)
            if idx == 1:
                print("\n[WARN] Thread not suspended here.", flush=True)
                print("  In attach/suspend=n mode, 'where' only works right after a breakpoint fires.", flush=True)
                print("  Avoid inserting 'cont' before 'where' — cont resumes the suspended thread.", flush=True)
        elif cmd == 'run':
            # Non-attach launch mode
            idx, out = sess.wait_for([BP_HIT_PAT, re.compile(r'VM started')], timeout=timeout)
        else:
            sess.wait_for_prompt(timeout=8)

    sess.close()
    print("\n[JDB session complete]", flush=True)


if __name__ == '__main__':
    main()

