# Development

See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution expectations and [AGENTS.md](../AGENTS.md) for repository layout and maintainer guidance.

## Local validation

The standard validation entry point is:

```sh
make check
```

Useful targets include:

```sh
make test
make linux-test
make linux-ci
make help
```

`make check` runs formatting, tests with warnings treated as errors, trait and DocC coverage validation, DocC generation, code coverage checks, and the Linux Docker build/test flow.

## Linux helpers

Docker Desktop on macOS or Docker Engine on Linux is required. The scripts use the pinned `swift:6.2.4-noble` image and keep Linux build artifacts separate from the host build.

```sh
Scripts/linux-shell.sh
Scripts/linux-build.sh
Scripts/linux-test.sh
Scripts/linux-ci.sh
```

On Apple Silicon, helpers use a native ARM container by default. To mirror GitHub Actions' amd64 Linux runner:

```sh
SWIFTYSHELL_LINUX_PLATFORM=linux/amd64 Scripts/linux-ci.sh --traits All
make linux-ci-amd64
```

## Example package

The standalone executable in [`Example/`](../Example/) uses the local checkout:

```sh
swift run --package-path Example
```

## Add a typed command family

The DocC [Building Command Families guide](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/buildingcommandfamilies) describes the API conventions. The shared assistant guidance is in [`.claude/skills/swiftyshell.md`](../.claude/skills/swiftyshell.md). When adding a family, update its SwiftPM trait, tests, DocC page, and the shared guidance where the public API or agent workflow changes.

## AI-assisted development

SwiftyShell provides a shared agent skill with API details and contribution conventions. See the DocC [Using AI Assistants guide](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/usingaiassistants) for prompt examples.
