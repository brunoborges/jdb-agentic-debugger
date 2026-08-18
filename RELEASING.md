# Releasing

`VERSION` is the authoritative project version. The repository validator requires
the same value in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
and `skills/jdb-debugger/SKILL.md`.

1. Update `VERSION` and all validated version fields.
2. Move relevant entries from `CHANGELOG.md` into a versioned section.
3. Run `./tests/run-unit-tests.sh` and ShellCheck.
4. Run authenticated Copilot and Claude evaluations, including a `--no-plugin`
   baseline, and retain the generated reports.
5. Verify installation from the release candidate plugin package.
6. Tag the validated commit with `v<VERSION>` and publish release notes from the
   changelog.

Benchmark reports must identify the commit, plugin version, date, OS, JDK, agent
CLI version, model, plugin/baseline mode, duration, and per-scenario results.
