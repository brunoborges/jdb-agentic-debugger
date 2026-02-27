# JDB Agentic Debugger

An AI agent plugin that teaches AI agents to debug Java applications in real time using [**JDB**](https://docs.oracle.com/en/java/javase/25/docs/specs/man/jdb.html) — the command-line debugger shipped with every JDK. Compatible with [GitHub Copilot CLI](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-coding-agent) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Why an Agentic Debugger?

AI coding agents are already powerful analysts. They can read source code, decompile `.class` files, run `javap` to inspect bytecode, and reason about what *should* happen at runtime. They can attach `jcmd`, `jstack`, and `jmap` to a live JVM to grab thread dumps, heap histograms, and GC stats — all without JDWP. When something goes wrong, they can insert print statements, re-run the program, and parse the output.

So why give them JDB on top of all that?

Because none of those tools give an agent **control over execution**. They produce snapshots — what the JVM looks like *right now* or *after the fact*. But many bugs require an agent to pause the program at a precise moment and interrogate it: What is this variable's value on *this* line? Which branch did the code actually take? What did the object look like *before* the method mutated it? That's what a debugger does — and only a debugger.

Specifically, JDB gives an agent capabilities no other JDK or OS tool provides:

- **Break on the exact moment of failure** — set a breakpoint on a line, method, or exception class, and the JVM *pauses right there*. Not a snapshot taken sometime after — the actual instant. The agent can then inspect locals, walk the call stack, and evaluate expressions against live objects in that frozen frame.
- **Step through execution line by line** — follow the actual path the code takes through polymorphic dispatch, reflection, and dynamically loaded classes. No other tool lets an agent say "execute one more line and show me what changed."
- **Evaluate expressions in context** — `print order.getItems().size()` or `eval config.getTimeout() * 2` against real objects on the current stack frame. This isn't heap analysis — it's interactive interrogation of live state at a precise point in execution.
- **Reproduce and isolate timing-dependent bugs** — a breakpoint *freezes* a thread mid-execution, letting an agent inspect a race condition or state corruption that no amount of thread dumps or logging can reliably capture, because those tools change timing or only show state after the fact.

Tools like `jcmd` and `jstack` tell an agent *what the JVM is doing*. JDB lets an agent *control what happens next*. That's the difference between monitoring and debugging — and it's why agents need both. JDB ships with every JDK, requires no IDE, and works over a simple text protocol, making it the ideal bridge between AI agents and live Java processes.

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
         └── jdb-analyst       → Analysis and report consolidation
```

| Agent | Role | Tools | User-Invocable |
|-------|------|-------|----------------|
| `JDB Debugger` | Orchestrator — triages requests, dispatches sub-agents in parallel | `read`, `search`, `agent`, `write` | Yes |
| `jdb-session` | Interactive JDB sessions (launch/attach), writes `findings-<Class>.md` | `execute`, `read`, `search`, `write` | No |
| `jdb-diagnostics` | Automated diagnostics collection | `execute`, `read` | No |
| `jdb-analyst` | Consolidates findings into `DEBUG-REPORT.md` | `read`, `search`, `write` | No |

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

#### Parallel Debugging

When multiple independent applications need debugging, the orchestrator dispatches one `jdb-session` sub-agent **per application in parallel**. Each sub-agent writes its findings to a `findings-<ClassName>.md` file. Once all sub-agents complete, the orchestrator hands off the findings files to `jdb-analyst` for consolidation into a single `DEBUG-REPORT.md`.

This file-based reporting avoids the problem of background agents whose text responses cannot be read back, and prevents duplicate work from re-dispatching.

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

# Debug with a timeout (for apps that may hang/deadlock)
bash skills/jdb-debugger/scripts/jdb-breakpoints.sh \
  --mainclass com.example.Main --classpath classes \
  --bp "catch java.lang.Exception" \
  --auto-inspect 10 --timeout 60
```

## Benchmark Results

See the [`results/`](results/) folder for benchmark comparisons between agent (parallel) and serial execution modes.

## Blog Posts & Announcements

- [Substack — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://brunocborges.substack.com/p/enabling-ai-agents-to-use-a-real)
- [LinkedIn — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://www.linkedin.com/pulse/enabling-ai-agents-use-real-debugger-instead-logging-bruno-borges-uty4e/)
- [Foojay — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://foojay.io/today/enabling-ai-agents-to-use-a-real-debugger-instead-of-logging/)
- [DEV Community — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://dev.to/brunoborges/enabling-ai-agents-to-use-a-real-debugger-instead-of-logging-bep)
- [Medium — Enabling AI Agents to Use a Real Debugger Instead of Logging](https://medium.com/@brunoborges/enabling-ai-agents-to-use-a-real-debugger-instead-of-logging-7d8250940845)
- [X/Twitter — Announcement](https://x.com/brunoborges/status/2023504791192617148)

## License

MIT
