#!/usr/bin/env python3
"""Validate manifests, agent front matter, versions, links, and executable scripts."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []


def error(message: str) -> None:
    errors.append(message)


version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    error("VERSION must contain a semantic version")

plugin = json.loads((ROOT / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))
marketplace = json.loads(
    (ROOT / ".claude-plugin/marketplace.json").read_text(encoding="utf-8")
)
skill = (ROOT / "skills/jdb-debugger/SKILL.md").read_text(encoding="utf-8")

if plugin.get("version") != version:
    error("plugin.json version differs from VERSION")
for entry in marketplace.get("plugins", []):
    if entry.get("version") != version:
        error("marketplace.json version differs from VERSION")
if f'version: "{version}"' not in skill:
    error("SKILL.md version differs from VERSION")

required_front_matter = {"name", "description", "tools"}
for agent in sorted((ROOT / "agents").glob("*.agent.md")):
    text = agent.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        error(f"{agent.relative_to(ROOT)} has no YAML front matter")
        continue
    keys = {
        line.split(":", 1)[0].strip()
        for line in match.group(1).splitlines()
        if line and not line.startswith((" ", "-"))
    }
    missing = required_front_matter - keys
    if missing:
        error(f"{agent.relative_to(ROOT)} missing fields: {sorted(missing)}")

for relative in plugin.get("agents", []):
    path = (ROOT / ".claude-plugin" / relative).resolve()
    if not path.is_file():
        error(f"plugin agent path does not exist: {relative}")

for script in sorted((ROOT / "skills/jdb-debugger/scripts").glob("*.sh")):
    if not os.access(script, os.X_OK):
        error(f"{script.relative_to(ROOT)} is not executable")

scenario_docs = (ROOT / "tests/scenarios/README.md").read_text(encoding="utf-8")
if "DeadlockTest" in scenario_docs:
    error("scenario documentation still references removed DeadlockTest")

instructions = (ROOT / ".github/copilot-instructions.md").read_text(encoding="utf-8")
if "jdb-debugger-agents/" in instructions or "jdb-debugger-skill/" in instructions:
    error("instructions reference unsupported legacy mirrors")

if errors:
    print("\n".join(f"ERROR: {item}" for item in errors), file=sys.stderr)
    raise SystemExit(1)
print("Repository metadata validation passed")
