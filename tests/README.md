# Tests — JDB Agentic Debugger

This directory contains the integration test framework for the jdb-agentic-debugger plugin. It validates that AI coding agents (Claude Code CLI and GitHub Copilot CLI) can autonomously debug Java applications using only compiled `.class` files — no source code access.

## Architecture Overview

```
tests/
├── prompt.txt              # The prompt given to each agent
├── prepare-test.sh         # Sets up an isolated directory for manual/interactive testing
├── run-test.sh             # Automated test runner with validation and reporting
├── scenarios/              # Intentionally buggy Java source files
│   ├── WarningAppTest.java
│   ├── ConsoleAppTest.java
│   ├── AliasingCorruptionTest.java
│   ├── ClassLoaderConflictTest.java
│   ├── ThreadTest.java
│   ├── VisibilityTest.java
│   └── README.md           # Details on each sample and how to run them manually
└── test-results/           # Output artifacts from test runs
    ├── DEBUG-REPORT-*.md   # Agent-generated bug reports (the artifact under test)
    └── test-report-*.txt   # Harness validation reports (pass/fail results)
```

## How It Works

### 1. Sample Programs (`scenarios/`)

The `scenarios/` directory contains Java programs with intentional bugs spanning several categories:

- **State bugs** — off-by-one counters, null corruption, wrong variable references
- **Input handling** — missing `trim()`, substring bounds errors
- **Concurrency** — deadlocks, thread visibility issues, illegal thread state
- **Object identity** — aliasing/shared-reference corruption, class loader conflicts

These are compiled with `javac -g` (debug symbols enabled) so that JDB can reference line numbers and local variables — but the agent never sees the `.java` source.

### 2. The Prompt (`prompt.txt`)

A standardized prompt instructs the agent to:

1. Run each application and observe its behavior
2. Use a debugger (JDB) to investigate — **not** `javap` or bytecode disassembly
3. Identify exception-based and runtime-behavior bugs
4. Produce a `DEBUG-REPORT.md` with title, symptom, method/line, root cause, and suggested fix for each bug

### 3. Test Execution (`run-test.sh`)

The automated test runner orchestrates end-to-end testing:

1. **Compiles** the sample Java files into a temp directory with debug symbols
2. **Sets up isolated work directories** for each agent, copying compiled classes and plugin files (agents, skills, scripts)
3. **Invokes the agent CLI** (Claude or Copilot) with the prompt, running it non-interactively
4. **Validates** the agent's `DEBUG-REPORT.md` against known bug indicators using pattern matching
5. **Produces** a test report with pass/fail results and timing

```bash
# Run with all available agents
./tests/run-test.sh

# Run with a specific agent
./tests/run-test.sh --agent copilot
./tests/run-test.sh --agent claude

# Additional options
./tests/run-test.sh --model <model>        # Override the LLM model
./tests/run-test.sh --max-budget <usd>     # Set max budget for Claude (default: $25)
./tests/run-test.sh --verbose              # Show agent output and preserve work dir
./tests/run-test.sh --allow-all            # Skip permission prompts
./tests/run-test.sh --no-plugin            # Run without plugin files (baseline test)
```

### 4. Interactive Preparation (`prepare-test.sh`)

For manual debugging and development, `prepare-test.sh` creates an isolated temp directory with everything needed to run an agent interactively:

```bash
./tests/prepare-test.sh            # Full setup with plugin files
./tests/prepare-test.sh --no-plugin  # Classes and prompt only

# Then follow the printed instructions to cd into the directory and launch an agent
```

#### Interactive Testing with GitHub Copilot CLI (Recommended)

Using the **JDB Debugger** agent with Copilot CLI produces faster results because it parallelizes debugging across sub-agents (`jdb-session`, `jdb-diagnostics`, `jdb-analyst`).

**Step-by-step process:**

1. **Run the prepare script** to compile the test scenarios and set up an isolated work directory:

   ```bash
   ./tests/prepare-test.sh
   ```

   The script will print the path to the temporary directory (e.g., `/tmp/jdb-test-XXXXXX`).

2. **Change into the temporary directory:**

   ```bash
   cd /tmp/jdb-test-XXXXXX
   ```

3. **Launch the Copilot CLI:**

   ```bash
   copilot
   ```

4. **Select a model** using the `/model` command:

   ```
   /model
   ```

   Pick the model you want to use from the list.

5. **Select the JDB Debugger agent** using the `/agent` command:

   ```
   /agent
   ```

   Select **JDB Debugger** from the list.

6. **Run the prompt** by asking the agent to read and follow the test instructions:

   ```
   Read the prompt.txt file and follow the instructions.
   ```

   The agent will autonomously run each Java application, use JDB to debug them, and produce a `DEBUG-REPORT.md` with its findings.

### 5. Validation Logic

The test harness checks the agent's `DEBUG-REPORT.md` against 5 expected bugs using keyword-based pattern matching. Each bug has a set of indicator patterns (e.g., `"nullpointerexception"`, `"clearhistory"`, `"trim"`). A bug is considered detected if a minimum number of its indicators appear in the report.

| Result | Criteria |
|--------|----------|
| ✅ PASS | 5/5 bugs detected |
| ⚠️ WARN | 3–4/5 bugs detected (acceptable) |
| ❌ FAIL | < 3/5 bugs detected |

### 6. Test Results (`test-results/`)

Each test run produces two files per agent, timestamped:

| File | Purpose |
|------|---------|
| `DEBUG-REPORT-<agent>-<timestamp>.md` | The agent's actual output — a detailed bug report with root cause analysis for each bug found. This is the artifact being evaluated. |
| `test-report-<agent>-<timestamp>.txt` | The harness's validation — shows PASS/FAIL per bug, indicator match counts, overall score, and run duration. |

## Prerequisites

- **JDK** with `javac` and `jdb` on `PATH`
- **Claude CLI** (`claude`) and/or **GitHub Copilot CLI** (`copilot`) installed and authenticated
