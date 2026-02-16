# jdb-debugger

An [Agent Skill](https://agentskills.io/specification) that teaches AI agents to debug Java applications in real time using JDB — the command-line debugger shipped with every JDK.

## What This Skill Does

When activated, this skill enables AI agents to:

- **Launch** a Java application under JDB for step-by-step debugging
- **Attach** to a running JVM with JDWP enabled (local or remote)
- **Set breakpoints** at lines, methods, constructors, or on exceptions
- **Step through code** — step into, step over, step up
- **Inspect variables** — locals, fields, expressions, full object dumps
- **Analyze threads** — thread dumps, deadlock detection, thread switching
- **Collect diagnostics** — automated thread dumps and class listings
- **Bulk set breakpoints** from a file for repeatable debugging sessions

## Skill Structure

```
jdb-debugger/
├── SKILL.md                        # Main skill instructions
├── scripts/
│   ├── jdb-launch.sh               # Launch a JVM under JDB
│   ├── jdb-attach.sh               # Attach JDB to a running JVM
│   ├── jdb-diagnostics.sh          # Collect thread dumps & diagnostics
│   └── jdb-breakpoints.sh          # Bulk-load breakpoints from a file
└── references/
    ├── jdb-commands.md              # Complete JDB command reference
    └── jdwp-options.md              # JDWP agent configuration options
```

## Quick Start

### Use with Claude Code

```bash
/skill install jdb-debugger
```

### Use with Claude.ai

Upload the `jdb-debugger/` directory as a custom skill via **Settings > Capabilities**.

### Use via API

Attach the skill directory to your API request per the [Skills API guide](https://docs.claude.com/en/api/skills-guide).

## Prerequisites

- **JDK** installed (any version with `jdb` — JDK 8+)
- **Bash** shell
- For remote debugging: the target JVM must be started with JDWP:
  ```bash
  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -jar myapp.jar
  ```

## Script Usage

All scripts support `--help` for full usage details.

```bash
# Launch a new JVM under JDB
bash scripts/jdb-launch.sh com.example.Main --sourcepath src/main/java

# Attach to a running JVM
bash scripts/jdb-attach.sh --port 5005

# Collect diagnostics
bash scripts/jdb-diagnostics.sh --port 5005 --output /tmp/diagnostics.txt

# Load breakpoints from file
bash scripts/jdb-breakpoints.sh --breakpoints my-breakpoints.txt --port 5005
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
