# Security policy

Please report vulnerabilities privately through GitHub Security Advisories for this
repository rather than opening a public issue.

Only the latest released version is supported with security fixes.

## JDWP safety

JDWP provides debugger-level control of a JVM and has no application-level
authentication. Never expose a JDWP port to an untrusted network. Use loopback,
network access controls, or an authenticated tunnel, and attach only with the
system owner's authorization. Breakpoints can suspend service threads, while JDB
expression evaluation can execute methods and mutate live state.
