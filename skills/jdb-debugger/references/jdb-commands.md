# JDB Command Reference

Complete alphabetical reference of all JDB commands.

## Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| `!!` | `!!` | Repeat last command |
| `catch` | `catch [uncaught\|caught\|all] <class>` | Break when the specified exception is thrown. `all` means both caught and uncaught. |
| `class` | `class <class-name>` | Display details of a named class |
| `classes` | `classes` | List all loaded classes |
| `classpath` | `classpath` | Print classpath info from target JVM |
| `clear` | `clear <class>:<line>` or `clear <class>.<method>[(args)]` | Remove a breakpoint. With no args, list all breakpoints. |
| `cont` | `cont` | Continue execution from a breakpoint |
| `down` | `down [n]` | Move down n frames in the call stack (default: 1) |
| `dump` | `dump <object>` | Print all fields of an object |
| `eval` | `eval <expression>` | Evaluate and print an expression (same as `print`) |
| `exit` | `exit` or `quit` | Exit JDB |
| `fields` | `fields <class>` | List all fields of a class |
| `gc` | `gc` | Request garbage collection |
| `help` | `help` or `?` | List available commands |
| `ignore` | `ignore <class>` | Do not stop for the specified exception |
| `interrupt` | `interrupt <thread>` | Interrupt a thread |
| `kill` | `kill <thread> <expression>` | Kill a thread with the given exception object |
| `list` | `list [line\|method]` | Print source code around current position or specified location |
| `locals` | `locals` | Print all local variables in the current stack frame |
| `lock` | `lock <object>` | Print lock info for an object |
| `methods` | `methods <class>` | List all methods of a class |
| `monitor` | `monitor <command>` | Execute a command each time the program stops |
| `next` | `next` | Step over — execute one line without entering called methods |
| `pop` | `pop` | Pop the current frame (if supported by JVM) |
| `print` | `print <expression>` | Print the value of an expression |
| `read` | `read <filename>` | Read and execute commands from a file |
| `redefine` | `redefine <class> <file.class>` | Redefine a class with new bytecode (hot-swap) |
| `reenter` | `reenter` | Pop and re-enter the current frame |
| `resume` | `resume [thread]` | Resume a suspended thread (or all threads) |
| `run` | `run [class [args]]` | Start the debugged application |
| `set` | `set <variable> = <expression>` | Set the value of a variable |
| `sourcepath` | `sourcepath [dirs]` | Show or set the source file search path |
| `step` | `step` | Step into — execute one line, entering method calls |
| `step up` | `step up` | Execute until the current method returns |
| `stop` | `stop at <class>:<line>` or `stop in <class>.<method>[(args)]` | Set a breakpoint. With no args, list all breakpoints. |
| `suspend` | `suspend [thread]` | Suspend a thread (or all threads) |
| `thread` | `thread <thread>` | Set the current thread |
| `threadgroup` | `threadgroup <name>` | Set the current thread group |
| `threadgroups` | `threadgroups` | List all thread groups |
| `threads` | `threads [group]` | List all threads (optionally in a specific group) |
| `trace` | `trace [go] methods [thread]` | Trace method entry/exit. `go` resumes after trace. |
| `unmonitor` | `unmonitor <n>` | Remove a monitor by index |
| `untrace` | `untrace [methods]` | Stop tracing |
| `up` | `up [n]` | Move up n frames in the call stack (default: 1) |
| `use` | `use [path]` | Set or show the source path (alias for `sourcepath`) |
| `version` | `version` | Print JDB version info |
| `where` | `where [all\|thread]` | Dump the call stack of the current thread, all threads, or a specific thread |
| `wherei` | `wherei [all\|thread]` | Same as `where` but includes pc (program counter) info |

## Expression Syntax

JDB supports a subset of Java expressions for `print`, `eval`, `dump`, and `set`:

- Local variables: `myVar`
- Field access: `myObj.field`
- Array access: `myArray[0]`
- Method calls: `myObj.toString()`
- Static fields: `java.lang.Integer.MAX_VALUE`
- Arithmetic: `x + 1`, `count * 2`
- String concatenation: `"prefix" + myVar`
- Casts: `((MyClass)obj).myMethod()`
- `this` reference: `this.field`

## Notes

- Most commands that accept a thread ID use the hex thread ID shown by `threads`
- The `read` command can execute a batch of commands from a file
- `monitor` commands run every time the JVM stops (breakpoint, step, etc.)
- `redefine` requires the JVM to support class redefinition (HotSwap)
