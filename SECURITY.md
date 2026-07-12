# Security Policy

SwiftyShell executes local commands and can affect the caller's filesystem, environment, and installed tools. Please report security issues privately so maintainers can investigate before details are public.

## Supported Versions

Security fixes target the current `0.3.x` release line and the `main` branch.

## Caller Security Boundary

SwiftyShell passes `Command` arguments as separate argv entries and does not invoke a shell unless the caller explicitly runs one. This prevents shell parsing of ordinary arguments, but it does not validate executable behavior or make untrusted input safe for `sh -c`, `python -c`, regular expressions, templates, tool-specific command strings, environment variables, executable overrides, or output paths.

Validate untrusted values according to the invoked tool's grammar, use allowlists for executables and privileged options, prefer absolute executable paths in sensitive contexts, avoid placing secrets in argv, and constrain writable paths before execution. Typed command families improve API discoverability; they are not a sandbox or authorization layer.

## Reporting a Vulnerability

If you believe you found a vulnerability, do not open a public issue. Contact the maintainer privately through GitHub or email the maintainer address listed on the project profile.

Useful reports include:

- A minimal reproduction
- The affected SwiftyShell version or commit
- The operating system and Swift version
- The expected and actual behavior
- Any known impact, such as unintended command execution, unsafe file writes, or leaked output

The maintainer will acknowledge the report when possible, investigate, and coordinate a fix or disclosure plan when the issue is confirmed.
