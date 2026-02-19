# Benchmark: Agent Workflow vs Serial Execution

**Date**: 2026-02-19
**Test Scenarios**: 6 Java applications (WarningAppTest, ConsoleAppTest, AliasingCorruptionTest, ClassLoaderConflictTest, ThreadTest, VisibilityTest)

## Timing

| Metric | Agent Workflow | Serial Execution |
|--------|---------------|-----------------|
| **Reported Start** | 21:23:31 UTC | 20:29:40 UTC |
| **Reported End** | 21:32:27 UTC | 21:07:07 UTC |
| **Reported Duration** | ~9 min | ~37 min |
| **Actual Duration (file timestamps)** | **~12 min** | **~37 min** |
| **Speedup** | **3x faster** | baseline |

> The agent workflow's reported 9 min is slightly optimistic — the analyst consolidation phase at the end adds ~3 min not captured in sub-agent timestamps.

## Bugs Found

| Application | Agent Workflow | Serial Execution |
|-------------|---------------|-----------------|
| WarningAppTest | 5 | 3 |
| ConsoleAppTest | 2 | 1 |
| AliasingCorruptionTest | 1 | 1 |
| ClassLoaderConflictTest | 1 | 1 |
| ThreadTest | 1 | 1 |
| VisibilityTest | 2 | 2 |
| **Total** | **12** | **9** |

## Bug Overlap Analysis

### Found by Both (9 bugs)

1. **WarningAppTest** — `clearHistory()` sets `warningHistory = null` instead of `.clear()` (NPE)
2. **WarningAppTest** — Preview uses wrong variable for `substring()` / short string issue
3. **WarningAppTest** — `warningCount` not incremented / count displayed incorrectly
4. **ConsoleAppTest** — Input not trimmed (trailing whitespace causes map lookup failure)
5. **AliasingCorruptionTest** — Shared mutable object reference reused across loop iterations
6. **ClassLoaderConflictTest** — `ClassCastException` from cross-classloader cast
7. **ThreadTest** — Deadlock from inconsistent lock ordering (LOCK_A/LOCK_B)
8. **VisibilityTest** — Non-volatile `stopRequested` field (JMM visibility bug)
9. **VisibilityTest** — `setDaemon()` called after `Thread.start()`

### Found Only by Agent Workflow (+3 bugs)

1. **WarningAppTest** — Empty string input causes `StringIndexOutOfBoundsException`
2. **WarningAppTest** — Null input not guarded (NPE in `processMessage()`)
3. **ConsoleAppTest** — Missing `STANDARD` tier in discount map

### Found Only by Serial Execution

None.

## File-Based Reporting

The agent workflow used `findings-*.md` file-based reporting:
- 6 findings files written (one per application), all present
- `jdb-analyst` sub-agent consolidated them into `DEBUG-REPORT.md`
- No evidence of duplicated sub-agent dispatches

## Summary

| Metric | Agent Workflow | Serial Execution |
|--------|---------------|-----------------|
| **Duration** | ~12 min | ~37 min |
| **Bugs Found** | 12 | 9 |
| **Bugs/Minute** | ~1.0 | ~0.24 |
| **Speedup** | **3x faster** | — |
| **Extra Bugs** | +3 (33% more) | — |
| **Missed Bugs** | 0 | 3 |

The agent workflow is **3x faster** and found **33% more bugs**, while missing none of the bugs found by the serial approach.
