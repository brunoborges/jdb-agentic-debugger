# JDB Agentic Debugger

An AI agent plugin that enables AI-powered Java debugging using JDB (Java Debugger). Compatible with Claude Code and GitHub Copilot CLI.

## Overview

This plugin provides a complete debugging solution for Java applications through Claude Code's agent system. It combines a powerful JDB skill with specialized agents to provide interactive debugging, diagnostics, and analysis capabilities.

## Features

### 🤖 AI Agents

The plugin includes four specialized agents working together:

1. **JDB Debugger** (Orchestrator)
   - Main entry point for all debugging tasks
   - Triages requests and delegates to appropriate specialist agents
   - Available in the agent picker

2. **jdb-session** (Interactive Debugger)
   - Launches JVMs under JDB or attaches to running processes
   - Sets breakpoints and steps through code
   - Inspects variables and evaluates expressions

3. **jdb-diagnostics** (Quick Diagnostics)
   - Collects thread dumps from running JVMs
   - Detects deadlocks
   - Lists loaded classes

4. **jdb-analyst** (Analysis Specialist)
   - Analyzes stack traces and thread dumps
   - Provides root cause analysis
   - Offers actionable recommendations

### 🛠️ JDB Skill

The plugin includes a comprehensive skill that teaches Claude how to:

- Launch Java applications under JDB
- Attach to running JVMs with JDWP enabled
- Set various types of breakpoints (line, method, exception)
- Step through code (into, over, up)
- Inspect variables, fields, and object state
- Analyze threads and detect deadlocks
- Execute diagnostic commands in batch mode

## Installation

### Claude Code CLI

```bash
# Add the marketplace
/plugin marketplace add brunoborges/jdb-agentic-debugger

# Install the plugin
/plugin install jdb-agentic-debugger@jdb-agentic-debugger
```

### GitHub Copilot CLI

The `.agent.md` files in `agents/` and the skill in `skills/jdb-debugger/` are compatible with GitHub Copilot coding agent. Copy the `agents/` files into your project's `.github/agents/` folder and use the **JDB Debugger** agent from the Copilot Chat agent picker.

## Usage

### Basic Debugging Workflow

1. **Select the JDB Debugger agent** from the agent picker in Claude Code chat

2. **Describe your debugging need:**
   ```
   "Debug the NullPointerException in MyClass.processData"
   ```

3. **Claude will:**
   - Analyze your code
   - Identify the issue location
   - Present handoff buttons for next steps

4. **Click a handoff button:**
   - **Debug interactively** → Launches JDB session
   - **Collect diagnostics** → Gets thread dump
   - **Analyze output** → Reviews stack traces

### Example Conversations

**Investigating an Exception:**
```
You: "I'm getting a StringIndexOutOfBoundsException in WarningAppTest.showWarning"

Claude: [Analyzes code, identifies the issue]
        [Presents handoff buttons]

You: [Click "Debug interactively"]

Claude: [Launches JDB with appropriate breakpoints]
        [Runs the code and captures the exception]
        [Shows variable values and stack trace]
        [Explains the root cause]
```

**Getting Diagnostics:**
```
You: "Take a thread dump of my app on port 5005"

Claude: [Presents handoff buttons]

You: [Click "Collect diagnostics"]

Claude: [Connects to JVM via JDWP]
        [Collects thread dump and deadlock info]
        [Displays formatted results]
```

**Analyzing a Stack Trace:**
```
You: "Here's a stack trace from production - what's wrong?
     [paste stack trace]"

Claude: [Presents handoff buttons]

You: [Click "Analyze output"]

Claude: [Analyzes the stack trace]
        [Identifies root cause]
        [Suggests fixes]
```

## Prerequisites

- **JDK installed** (any version with `jdb` — JDK 8+)
- **Bash shell** (Linux/macOS native, Windows via WSL)
- **Target JVM with JDWP enabled** for remote debugging:
  ```bash
  java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \
       -jar myapp.jar
  ```

## Direct Script Usage

You can also use the skill scripts directly without going through agents:

```bash
# Launch a new JVM under JDB
bash skills/jdb-debugger/scripts/jdb-launch.sh com.example.Main \
  --sourcepath src/main/java

# Attach to a running JVM
bash skills/jdb-debugger/scripts/jdb-attach.sh --port 5005

# Collect diagnostics
bash skills/jdb-debugger/scripts/jdb-diagnostics.sh --port 5005

# Load breakpoints from file
bash skills/jdb-debugger/scripts/jdb-breakpoints.sh \
  --mainclass com.example.Main \
  --bp "stop at com.example.Main:42" \
  --bp "catch java.lang.NullPointerException"
```

All scripts support `--help` for full usage details.

## Windows Support

On Windows, invoke scripts via WSL:

```bash
wsl bash skills/jdb-debugger/scripts/jdb-launch.sh com.example.MyApp
```

Ensure JDK is installed in WSL:
```bash
# Ubuntu/Debian WSL
sudo apt update && sudo apt install -y default-jdk

# Verify
which jdb && jdb -version
```

## Plugin Structure

```
jdb-agentic-debugger/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── agents/
│   ├── jdb-debugger.agent.md    # Orchestrator
│   ├── jdb-session.agent.md     # Interactive debugger
│   ├── jdb-diagnostics.agent.md # Quick diagnostics
│   └── jdb-analyst.agent.md     # Analysis specialist
├── skills/
│   └── jdb-debugger/
│       ├── SKILL.md              # Skill instructions
│       ├── scripts/              # JDB wrapper scripts
│       └── references/           # JDB command reference
└── sample-app/                   # Example Java app for testing
```

## Advanced Features

### Batch Mode Debugging

Use `--auto-inspect` for automated debugging sessions:

```bash
bash skills/jdb-debugger/scripts/jdb-breakpoints.sh \
  --mainclass com.example.MyClass \
  --bp "catch java.lang.NullPointerException" \
  --bp "stop at com.example.MyClass:42" \
  --auto-inspect 20
```

This automatically:
1. Starts the JVM under JDB
2. Sets all breakpoints
3. Runs the application
4. On each breakpoint: shows stack trace + locals
5. Continues 20 times
6. Exits and returns full output

### Custom Commands

Use `--cmd` flags for precise control:

```bash
bash skills/jdb-debugger/scripts/jdb-breakpoints.sh \
  --mainclass com.example.MyClass \
  --bp "stop at com.example.MyClass:42" \
  --cmd "run" \
  --cmd "locals" \
  --cmd "print myVar" \
  --cmd "cont" \
  --cmd "quit"
```

### Remote Debugging

Debug applications running on remote servers:

```bash
# On remote server
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \
     -jar myapp.jar

# In Claude Code (or directly)
bash skills/jdb-debugger/scripts/jdb-attach.sh \
  --host remote-server.example.com \
  --port 5005
```

## Tips & Best Practices

1. **Compile with debug info:** Use `javac -g` to ensure local variable information is available
2. **Set source path:** Use `--sourcepath` so JDB can show source code
3. **Start simple:** Begin with basic breakpoints before complex scenarios
4. **Use batch mode:** For reproducible debugging, use `--auto-inspect` or `--cmd` flags
5. **Check JDWP first:** Ensure target JVM has JDWP enabled before attaching

## Troubleshooting

### "Unable to attach"
- Verify the JVM is running with JDWP agent
- Check the port number matches
- Ensure no firewall is blocking the connection

### "Local variable information not available"
- Recompile with `javac -g`
- Ensure classes on classpath match source

### "Source not found"
- Set source path with `--sourcepath` or `use` command in JDB
- Verify source files are at specified location

## Contributing

Issues and pull requests welcome at:
https://github.com/brunoborges/jdb-agentic-debugger

## License

Apache-2.0

## Resources

- [JDB Command Reference](skills/jdb-debugger/references/jdb-commands.md)
- [JDWP Options Reference](skills/jdb-debugger/references/jdwp-options.md)
- [Blog Post: Enabling AI Agents to Use a Real Debugger](https://brunocborges.substack.com/p/enabling-ai-agents-to-use-a-real)
