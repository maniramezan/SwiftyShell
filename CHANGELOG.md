# Changelog

All notable changes to SwiftyShell are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-24

Initial public release.

### Added

- `Core` execution primitives: `Command`, `Pipeline`, `ShellContext`, `ShellPlatform`, `ShellOutput`, `OutputDestination`, `ShellError`, `Workflow`.
- `CommandExecutor` protocol with two shipped implementations: `SubprocessExecutor` (default) and `MockExecutor` (for tests).
- Command-family protocol hierarchy: `ToolConfigurableCommandFamily`, `OutputRedirectingCommandFamily`, `RunnableCommandFamily`, plus shared `ToolConfiguration` carrier.
- `FileMode` value type for typed POSIX permissions with owner/group/other permission sets and special bits.
- Typed command families, each gated behind a SwiftPM package trait:
  - `Git` — `git status` with `porcelain=v2` parsing, `GitStatusWorkflow` gates, `pull`, `fetch`, `branch`, `stash`, `worktree`, `diff`, `log`, `config`, `merge`, `commit`, `rebase`.
  - `Brew` — full Homebrew subcommand coverage including `--cask` and `--greedy`.
  - `Grep` — literal and extended-regex patterns, recursive, case-insensitive, line numbers, counts, invert match.
  - `Common/*` — `Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Jq`.
- Umbrella traits: `CommonUtilities` (all `Common/*` families) and `All` (every family).
- `Scripts/validate-traits.swift` — structural validator enforcing the trait wiring contract, run in CI before any build.
- Build/test matrix across empty, per-family, `CommonUtilities`, and `All` traits on macOS 15 and Linux (Swift 6.1).
- DocC catalog with articles: `GettingStarted`, `SelectingCommandFamilies`, `CoreConcepts`, `ErrorHandling`, `BuildingCommandFamilies`, `UsingAIAssistants`.
- `Example/` — standalone SwiftPM executable demonstrating SwiftyShell via a local path reference.

### Execution semantics

- Timeouts enforced via `DispatchSourceTimer` on a dedicated queue so the escalation fires at wall-clock time even under cooperative-pool saturation.
- Graceful termination: `SIGTERM` on timeout or task cancellation, followed by `SIGKILL` after a short grace period.
- `stdin` is always closed (`/dev/null`) for spawned processes; interactive stdin is out of scope for v1.
- UTF-8 strict decoding for captured streams; invalid bytes surface as `ShellError.decodingError`.
- Default output-capture limit of 10 MiB; exceeding the limit drains the child output and throws `ShellError.outputLimitExceeded` with partial output.
- Pipelines terminate remaining stages when any stage exits non-zero.

[Unreleased]: https://github.com/maniramezan/SwiftyShell/compare/0.1.0...HEAD
[0.1.0]: https://github.com/maniramezan/SwiftyShell/releases/tag/0.1.0
