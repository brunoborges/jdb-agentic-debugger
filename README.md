# JDB Agentic Debugger

An AI agent plugin that teaches AI agents to debug Java applications in real time using JDB — the command-line debugger shipped with every JDK. Compatible with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [GitHub Copilot CLI](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-coding-agent).

## See demo

https://github.com/user-attachments/assets/7b2e4e69-8067-4519-bb6d-03c408a0be8a

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

### Claude Code CLI

```bash
# Add the marketplace
/plugin marketplace add brunoborges/jdb-agentic-debugger

# Install the plugin
/plugin install jdb-agentic-debugger@jdb-agentic-debugger
```

### GitHub Copilot CLI

The `.agent.md` files in `agents/` and the skill in `skills/jdb-debugger/` are compatible with [GitHub Copilot coding agent](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-coding-agent). To use them:

1. Copy the `agents/` files into your project's `.github/agents/` folder
2. Copy the `skills/jdb-debugger/` directory into your project (or reference it)
3. Open Copilot Chat and select the **JDB Debugger** agent from the agent picker

## Repository Structure

```
jdb-agentic-debugger/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest (Claude Code)
│   └── marketplace.json         # Marketplace catalog
├── agents/
│   ├── jdb-debugger.agent.md    # Orchestrator — triages and delegates
│   ├── jdb-session.agent.md     # Interactive debugging sub-agent
│   ├── jdb-diagnostics.agent.md # Quick diagnostics sub-agent
│   └── jdb-analyst.agent.md     # Read-only analysis sub-agent
├── skills/
│   └── jdb-debugger/
│       ├── SKILL.md              # Main skill instructions
│       ├── scripts/              # JDB wrapper scripts
│       └── references/           # JDB command reference
├── sample-app/                   # Example Java app for testing
└── docs/
    └── demo.mp4                  # Demo video
```

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

Apache-2.0
