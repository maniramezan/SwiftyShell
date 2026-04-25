# Security Policy

SwiftyShell executes local commands and can affect the caller's filesystem, environment, and installed tools. Please report security issues privately so maintainers can investigate before details are public.

## Supported Versions

During the `0.x` beta period, security fixes target the latest released version and the `main` branch.

## Reporting a Vulnerability

If you believe you found a vulnerability, do not open a public issue. Contact the maintainer privately through GitHub or email the maintainer address listed on the project profile.

Useful reports include:

- A minimal reproduction
- The affected SwiftyShell version or commit
- The operating system and Swift version
- The expected and actual behavior
- Any known impact, such as unintended command execution, unsafe file writes, or leaked output

The maintainer will acknowledge the report when possible, investigate, and coordinate a fix or disclosure plan when the issue is confirmed.
