# Copilot Instructions — JDB Agentic Debugger

## What This Repository Is

This is an **AI agent plugin** (not a Java application). It teaches AI coding agents (GitHub Copilot CLI, Claude Code) to debug Java applications using JDB — the CLI debugger shipped with every JDK. The repo contains no application code; it consists entirely of agent definitions, skill documents, and Bash scripts.

## Architecture

```
User → JDB Debugger (orchestrator agent)
         ├── jdb-session       → Interactive debugging (launch/attach, breakpoints, stepping)
         ├── jdb-diagnostics   → Quick JVM health checks (thread dumps, deadlock detection)
         └── jdb-analyst       → Read-only analysis (stack traces, root cause reports)
```

- **`agents/`** — Agent definition files (`.agent.md`) for the orchestrator and 3 sub-agents. Referenced by `plugin.json`.
- **`skills/jdb-debugger/`** — The JDB skill: `SKILL.md` (agent instructions), `scripts/` (4 Bash scripts), `references/` (JDB/JDWP docs).
- **`jdb-debugger-agents/`** and **`jdb-debugger-skill/`** — Legacy mirrors of `agents/` and `skills/jdb-debugger/`. Must be kept in sync for VS Code Copilot and standalone skill users.
- **`.claude-plugin/plugin.json`** — Claude Code plugin manifest. Points to agents in `agents/`.
- **`tests/`** — Integration test framework that validates agents can autonomously debug intentionally buggy Java programs.

## Key Conventions

- **Agents must never run raw `jdb` commands.** All JDB operations go through the 4 scripts in `skills/jdb-debugger/scripts/` (`jdb-launch.sh`, `jdb-attach.sh`, `jdb-breakpoints.sh`, `jdb-diagnostics.sh`).
- **Agents must never create files in the workspace.** Use inline CLI flags (`--bp`, `--cmd`, `--auto-inspect`) instead of temp files for breakpoints or commands.
- **Agent files use YAML front matter** with fields: `name`, `description`, `tools`, and optionally `agents`/`handoffs`.
- **The orchestrator (`jdb-debugger.agent.md`) never executes commands** — it only triages and delegates via handoffs.

## Running Tests

Tests are Bash-based integration tests that run AI agents against compiled Java programs with known bugs.

```bash
# Full test suite (all available agents)
./tests/run-test.sh

# Single agent
./tests/run-test.sh --agent copilot
./tests/run-test.sh --agent claude

# With options
./tests/run-test.sh --agent copilot --verbose --model <model>

# Prepare an isolated directory for manual/interactive testing
./tests/prepare-test.sh
```

Test scenarios are in `tests/scenarios/` — Java files with intentional bugs (state bugs, concurrency, aliasing, input handling). They are compiled with `javac -g` for debug symbols.

## Editing Guidelines

- When modifying agent or skill files, update both the canonical location (`agents/`, `skills/jdb-debugger/`) **and** the legacy mirrors (`jdb-debugger-agents/`, `jdb-debugger-skill/`).
- Script changes must preserve the `--help` flag behavior and the existing CLI flag interface (`--bp`, `--cmd`, `--auto-inspect`, `--port`, `--host`, `--sourcepath`, `--classpath`, `--mainclass`).
- The `plugin.json` manifest references agents by relative path from `.claude-plugin/` — keep paths consistent if renaming.
