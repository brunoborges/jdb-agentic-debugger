# Contributing

Contributions should preserve the public script flags and the rule that agents use
the provided scripts rather than invoking JDB directly.

## Validation

Run the deterministic suite before submitting a change:

```bash
./tests/run-unit-tests.sh
```

If ShellCheck is installed, also run:

```bash
shellcheck skills/jdb-debugger/scripts/*.sh tests/*.sh
```

Changes to scenarios or agent behavior should also run the relevant authenticated
evaluation described in `tests/README.md`. Do not commit generated reports.

Agent and skill files have one canonical location: `agents/` and
`skills/jdb-debugger/`. There are no maintained legacy mirrors.
