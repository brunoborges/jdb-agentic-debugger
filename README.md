# JDB Agentic Debugger

An AI agent plugin that teaches AI agents to debug Java applications in real time using [**JDB**](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jdb.html) — the command-line debugger shipped with every JDK. Compatible with [GitHub Copilot CLI](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-coding-agent) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Why an Agentic Debugger?

AI coding agents are already powerful static analysts. They can read source code, decompile `.class` files, run `javap` to inspect bytecode, parse stack traces, and reason about what *should* happen at runtime. When that isn't enough, they insert print statements, re-run the program, and parse the output — iterating until they converge on the bug.

So why give them a debugger?

Because **static analysis and logging can only tell you what the code *says* — a debugger tells you what the code *does*.** Many bugs live in the gap between the two: race conditions that depend on thread scheduling, state corruption that builds up across hundreds of method calls, environment-specific behavior driven by configuration or classloader ordering, or failures deep inside third-party libraries where decompiled code is hard to follow. These bugs don't yield to reading; they have to be caught in the act.

A debugger attached to a **live, running application** gives an agent capabilities that no amount of static reasoning can replicate:

- **Observe actual runtime state** — variable values, object graphs, and thread states as they exist at a specific moment in execution, not as the agent infers they *might* be.
- **Catch the exact moment of failure** — break on an exception the instant it's thrown, before it propagates and gets wrapped, rather than reasoning backwards from a stack trace.
- **Follow real execution flow** — step through the actual path the code takes, including polymorphic dispatch, reflection, and dynamically loaded classes that are invisible to static analysis.
- **Inspect without modifying** — no print statements to add, commit, and later clean up. No risk of Heisenbugs caused by logging changing timing or behavior. The codebase stays untouched.
- **Debug live environments** — attach to a running JVM in staging or production to investigate issues that only reproduce under real load, real data, and real configuration — something print-and-rerun simply cannot do.

Decompilers and bytecode tools help an agent understand *structure*. A debugger helps it understand *behavior*. The combination is what makes an agent a genuinely effective debugger, not just a code reader that guesses well. JDB ships with every JDK, requires no IDE, and works over a simple text protocol — making it the ideal bridge between AI agents and live Java processes.

## What This Plugin Does

When activated, this plugin enables AI agents to:

- **Launch** a Java application under JDB for step-by-step debugging
- **Attach** to a running JVM with JDWP enabled (local or remote)
- **Set breakpoints** at lines, methods, constructors, or on exceptions
- **Step through code** — step into, step over, step up
- **Inspect variables** — locals, fields, expressions, full object dumps
- **Analyze threads** — thread dumps, deadlock detection, thread switching
- **Collect diagnostics** — automated thread dumps and class listings
- **Bulk set breakpoints** from a file for repeatable debugging sessions

## Quick Start

### GitHub Copilot :: Claude Code CLI

```bash
# Add the marketplace
/plugin marketplace add brunoborges/jdb-agentic-debugger

# Install the plugin
/plugin install jdb-agentic-debugger@jdb-agentic-debugger
```

### GitHub Copilot Coding Agents :: Visual Studio Code

The `.agent.md` files in `agents/` and the skill in `skills/jdb-debugger/` are compatible with [GitHub Copilot coding agent](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-coding-agent). To use them:

1. Copy the `agents/` files into your project's `.github/agents/` folder
2. Copy the `skills/jdb-debugger/` directory into your project (or reference it)
3. Open Copilot Chat and select the **JDB Debugger** agent from the agent picker

## Agents

The plugin includes a multi-agent chain for orchestrated Java debugging workflows. The agents are defined as `.agent.md` files in the `agents/` directory and work with both Claude Code and GitHub Copilot.

### Agent Architecture

```
User → JDB Debugger (orchestrator)
         ├── jdb-session       → Interactive debugging (launch/attach, breakpoints, stepping)
         ├── jdb-diagnostics   → Quick JVM health checks (thread dumps, deadlock detection)
         └── jdb-analyst       → Read-only analysis (stack traces, root cause reports)
```

| Agent | Role | Tools | User-Invocable |
|-------|------|-------|----------------|
| `JDB Debugger` | Orchestrator — triages requests and delegates | `read`, `search`, `agent` | Yes |
| `jdb-session` | Interactive JDB sessions (launch/attach) | `execute`, `read`, `search` | No |
| `jdb-diagnostics` | Automated diagnostics collection | `execute`, `read` | No |
| `jdb-analyst` | Read-only analysis of traces and logs | `read`, `search` | No |

### Usage

1. Select the **JDB Debugger** agent (or install the plugin and it becomes available)
2. Describe what you need:
   - *"Debug the NullPointerException in WarningAppTest"* → routes to `jdb-session`
   - *"Collect a thread dump from port 5005"* → routes to `jdb-diagnostics`
   - *"Analyze this stack trace"* → routes to `jdb-analyst`

### How the Agent Flow Works

The **JDB Debugger** agent is the orchestrator — you interact with it directly, and it delegates to the appropriate sub-agent based on your request. You never need to invoke `jdb-session`, `jdb-diagnostics`, or `jdb-analyst` manually; they are **not user-invocable**.

1. **Start a conversation** with the **JDB Debugger** agent.
2. **Describe your debugging need** in natural language.
3. **The orchestrator triages** your request and gathers context.
4. **The orchestrator hands off** to the right sub-agent.

#### Handoff Buttons

| Button Label | Sub-Agent | What Happens |
|---|---|---|
| **Debug interactively** | `jdb-session` | Starts an interactive JDB session — launches a JVM under JDB or attaches to a running one, sets breakpoints, and steps through code. |
| **Collect diagnostics** | `jdb-diagnostics` | Runs `jdb-diagnostics.sh` against a running JVM to collect thread dumps, deadlock info, and class listings. |
| **Analyze output** | `jdb-analyst` | Analyzes stack traces, thread dumps, or log output — read-only, no commands are executed. |

#### Example Workflow

```
You:    "Debug the StringIndexOutOfBoundsException in WarningAppTest"

  ┌─ JDB Debugger (orchestrator) ─────────────────────────────────┐
  │ Reads WarningAppTest.java, identifies the bug in showWarning  │
  │ at text.substring(0,3) without bounds check.                  │
  │                                                               │
  │ Presents handoff buttons:                                     │
  │   [Debug interactively]  [Collect diagnostics]  [Analyze]     │
  └───────────────────────────────────────────────────────────────┘

You click: [Debug interactively]

  ┌─ jdb-session ─────────────────────────────────────────────────┐
  │ Launches JDB with breakpoints on WarningAppTest using:        │
  │   bash skills/jdb-debugger/scripts/jdb-breakpoints.sh         │
  │     --mainclass com.example.WarningAppTest                    │
  │     --bp "catch java.lang.StringIndexOutOfBoundsException"    │
  │     --bp "stop at com.example.WarningAppTest:43"              │
  │     --auto-inspect 20                                         │
  │                                                               │
  │ Reports variable values, call stack, and root cause.          │
  └───────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **JDK** installed (any version with `jdb` — JDK 8+)
- **Bash** shell (Linux/macOS native, Windows via WSL)
- For remote debugging: the target JVM must be started with JDWP:
  ```bash
  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -jar myapp.jar
  ```

## Script Usage

All scripts support `--help` for full usage details.

```bash
# Launch a new JVM under JDB
bash skills/jdb-debugger/scripts/jdb-launch.sh com.example.Main --sourcepath src/main/java

# Attach to a running JVM
bash skills/jdb-debugger/scripts/jdb-attach.sh --port 5005

# Collect diagnostics
bash skills/jdb-debugger/scripts/jdb-diagnostics.sh --port 5005 --output /tmp/diagnostics.txt

# Load breakpoints from file
bash skills/jdb-debugger/scripts/jdb-breakpoints.sh --breakpoints my-breakpoints.txt --port 5005
```

## Blog Posts & Announcements

- [Substack — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://brunocborges.substack.com/p/enabling-ai-agents-to-use-a-real)
- [LinkedIn — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://www.linkedin.com/pulse/enabling-ai-agents-use-real-debugger-instead-logging-bruno-borges-uty4e/)
- [Foojay — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://foojay.io/today/enabling-ai-agents-to-use-a-real-debugger-instead-of-logging/)
- [DEV Community — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://dev.to/brunoborges/enabling-ai-agents-to-use-a-real-debugger-instead-of-logging-bep)
- [Medium — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://medium.com/@brunoborges/enabling-ai-agents-to-use-a-real-debugger-instead-of-logging-7d8250940845)
- [X/Twitter — Announcement](https://x.com/brunoborges/status/2023504791192617148)

## License

MIT
