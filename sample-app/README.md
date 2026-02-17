# Sample App — JDB Testing Application

A simple console application with **intentional bugs** for testing the `jdb-debugger` plugin.

## Build & Run

```bash
cd sample-app

# Compile
javac -g -d out src/main/java/com/example/WarningAppTest.java

# Run normally
java -cp out com.example.WarningAppTest

# Run with JDWP for remote debugging
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -cp out com.example.WarningAppTest
```

## Intentional Bugs

| # | Bug | How to Trigger | Expected Symptom |
|---|-----|----------------|------------------|
| 1 | `NullPointerException` | Click "Show Warning" with empty input | `processMessage` returns `null`, then `showWarning` passes it to `JOptionPane` |
| 2 | Off-by-one counter | Click "Show Warning" with any text | Counter always shows one less than actual |
| 3 | `NullPointerException` after clear | Click "Clear History", then "Show Warning" | `warningHistory` is set to `null` instead of cleared |
| 4 | `StringIndexOutOfBoundsException` | Enter text shorter than 3 characters (e.g., "Hi") | `substring(0, 3)` on a 2-char string |

## Debugging Exercises

Use the `jdb-debugger` skill to:

1. **Catch the NPE**: `catch java.lang.NullPointerException`, then trigger bug #1
2. **Watch the counter**: Set `stop at com.example.WarningAppTest:50` and inspect `warningCount`
3. **Find the memory leak**: Set breakpoint in `clearHistory()` and inspect `warningHistory`
4. **Catch bounds error**: `catch java.lang.StringIndexOutOfBoundsException`, enter "Hi"
