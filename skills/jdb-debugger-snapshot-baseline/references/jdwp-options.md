# JDWP Agent Options Reference

The Java Debug Wire Protocol (JDWP) agent enables remote debugging of a JVM. It is activated by passing the `-agentlib:jdwp` option when starting the JVM.

## Syntax

```
java -agentlib:jdwp=<option1>=<value1>,<option2>=<value2>,... MyApp
```

## Options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `transport` | `dt_socket`, `dt_shmem` | (required) | Transport mechanism. `dt_socket` for TCP/IP, `dt_shmem` for shared memory (Windows only). |
| `server` | `y`, `n` | `n` | If `y`, the JVM listens for debugger connections. If `n`, the JVM connects to a debugger. |
| `address` | `host:port` or `port` | (required if `server=n`) | For `server=y`: the port (or `host:port`) to listen on. For `server=n`: the address to connect to. Use `*:port` to listen on all interfaces. |
| `suspend` | `y`, `n` | `y` | If `y`, the JVM suspends until a debugger attaches. If `n`, the JVM runs immediately. |
| `timeout` | milliseconds | (none) | Timeout for debugger connection in milliseconds. |
| `onthrow` | exception class | (none) | Start JDWP agent when the specified exception is thrown. |
| `onuncaught` | `y`, `n` | `n` | Start JDWP agent on uncaught exceptions. |
| `launch` | command | (none) | Command to execute when JDWP events occur (used with `onthrow`/`onuncaught`). |
| `quiet` | `y`, `n` | `n` | Suppress the "Listening for transport..." message. |

## Common Configurations

### Development (local debugging)

Listen on port 5005, suspend until debugger connects:
```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005 MyApp
```

### Development (non-blocking)

Listen on port 5005, run immediately:
```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005 MyApp
```

### Remote debugging (listen on all interfaces)

```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 MyApp
```

### Production-safe (trigger on exception)

Only enable debugging when a specific exception is thrown:
```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,onthrow=java.lang.OutOfMemoryError,address=*:5005 MyApp
```

### Container / Kubernetes

```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -jar /app/myapp.jar
```

Expose the port in Dockerfile:
```dockerfile
EXPOSE 5005
```

And in the Kubernetes deployment:
```yaml
ports:
  - containerPort: 5005
    name: jdwp
```

## Security Considerations

- **Never expose JDWP on public interfaces in production** — JDWP has no authentication and allows arbitrary code execution.
- Use `address=127.0.0.1:5005` to bind to localhost only.
- Use SSH tunneling for remote debugging: `ssh -L 5005:localhost:5005 user@remote-host`
- Use `address=*:5005` only in trusted networks or containers with network policies.
- Consider the `onthrow`/`onuncaught` options to only activate the agent when needed.

## JDK Version Differences

| JDK Version | Default `address` Behavior |
|-------------|---------------------------|
| JDK 8 and earlier | `address=5005` listens on all interfaces |
| JDK 9+ | `address=5005` listens on localhost only. Use `address=*:5005` for all interfaces. |

## Environment Variable Alternative

Set JDWP globally for all Java processes in the shell:
```bash
export JAVA_TOOL_OPTIONS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
```

**Warning**: This affects ALL Java processes started in that shell, including build tools like Maven and Gradle.
