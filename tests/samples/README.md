# Sample App — JDB Debugging Playground

This folder contains intentionally buggy Java programs designed for debugger-driven investigation with `jdb-agentic-debugger`.

All classes are in the **default package**.

## Files

- `WarningAppTest.java` — multi-scenario bug demo (null handling, bounds, off-by-one, state corruption)
- `ConsoleAppTest.java` — simple branch/lookup demo for step-through practice
- `VisibilityTest.java` — Java Memory Model visibility bug (`volatile` missing)
- `DeadlockTest.java` — deterministic two-thread deadlock
- `ClassLoaderConflictTest.java` — same class name, different class loaders (`X cannot be cast to X`)
- `AliasingCorruptionTest.java` — data corruption from mutable object aliasing

## Compile

From `tests/samples/`:

```bash
mkdir -p out
javac -g -d out WarningAppTest.java ConsoleAppTest.java VisibilityTest.java DeadlockTest.java ClassLoaderConflictTest.java
javac -g -d out AliasingCorruptionTest.java
```

## Quick Run

```bash
java -cp out WarningAppTest
java -cp out ConsoleAppTest BASIC
java -cp out VisibilityTest
java -cp out DeadlockTest
java -cp out ClassLoaderConflictTest
java -cp out AliasingCorruptionTest
```

## Run with JDWP (attach debugger)

Use one test per terminal session (all default to port `5005`):

```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out WarningAppTest
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out ConsoleAppTest BASIC
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out VisibilityTest
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out DeadlockTest
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out ClassLoaderConflictTest
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out AliasingCorruptionTest
```

## What Each Demo Teaches

### WarningAppTest

Scenarios are executed in sequence from `main`:

1. Normal input shows off-by-one counter output
2. Empty input triggers `StringIndexOutOfBoundsException`
3. Short input triggers `StringIndexOutOfBoundsException`
4. Clear then show triggers `NullPointerException` from corrupted history state
5. Null input triggers `NullPointerException` in `message.trim()`

Use this for breakpoint placement, exception catchpoints, and state inspection across multiple failures.

### ConsoleAppTest

Tier-to-discount lookup (`BASIC`, `PREMIUM`, `VIP`) with default `0%` for unknown tier.

Examples:

```bash
java -cp out ConsoleAppTest BASIC
java -cp out ConsoleAppTest VIP
java -cp out ConsoleAppTest UNKNOWN
java -cp out ConsoleAppTest
```

Use this for basic stepping and variable inspection.

### VisibilityTest (runtime-only class of bug)

Demonstrates a visibility issue using a non-`volatile` shared flag (`stopRequested`).

Why debugger helps: static reading is insufficient to prove a failing inter-thread observation on a given run.

Debug focus:
- Compare `stopRequested` and `counter` across threads
- Inspect worker thread state after `join(1000)`

### DeadlockTest (runtime-only class of bug)

Two threads acquire locks in opposite order and deadlock.

Why debugger helps: lock ownership and wait graph are runtime properties.

Debug focus:
- Inspect thread states and monitor ownership
- Confirm circular wait between `deadlock-t1` and `deadlock-t2`

### ClassLoaderConflictTest (runtime-only class of bug)

Loads the same binary name through two isolated class loaders and forces cast failure.

Why debugger helps: class identity includes class loader, not only class name.

Debug focus:
- Compare `classA.getClassLoader()` vs `classB.getClassLoader()`
- Inspect runtime type identity during cast

### AliasingCorruptionTest

Demonstrates data corruption by reusing one mutable object (`OrderLine`) while adding it multiple times to a list.

Why debugger helps: runtime object identity reveals that all rows reference the same instance, even though the output appears to be separate records.

Debug focus:
- Inspect object identity (`System.identityHashCode`) for each list entry
- Watch `reused.product` and `reused.quantity` across loop iterations
- Confirm all list slots reference the same `OrderLine` object

## Suggested JDB Commands

```text
threads
where all
catch java.lang.NullPointerException
catch java.lang.StringIndexOutOfBoundsException
```

For single-step sessions, launch with one test class and set breakpoints by line in the corresponding file.
