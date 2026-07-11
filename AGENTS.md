# SwiftyShell — Agent Guide

This file is maintainer-oriented automation guidance for AI assistants working in this repository. It is public so contributors can audit and improve it, but it is optional and not required to build, test, or contribute to SwiftyShell.

SwiftyShell is a Swift package that provides type-safe shell command execution. It models shell concepts — commands, arguments, pipelines, redirection, workflows — as Swift values rather than raw strings.

## Repository Layout

### `Sources/SwiftyShell/Core/`

The execution primitives: `Command`, `Pipeline`, `SpawnedProcess`, `ProcessSignal`, `TeardownStrategy`, `ProcessTeardownStep`, `ShellContext`, `ShellPlatform`, `Workflow`, `ShellError`, `ShellOutput`, `OutputDestination`, `CommandExecutor`, `MockExecutor`, `MockSpawnedProcess`, `ToolConfiguration`, and the `ToolConfigurableCommandFamily` / `OutputRedirectingCommandFamily` / `RunnableCommandFamily` protocol hierarchy.

### `Sources/SwiftyShell/Git/`

Typed git client: `Git`, `GitStatus`, `GitStatusWorkflow`, `GitSubmodule`, `GitSubmoduleStatusEntry`, `GitPullResult`, `GitFetchResult`, `GitWorkingTreeState`, and the internal `GitParsers` porcelain v2 parser.

### `Sources/SwiftyShell/Grep/`

Typed `grep` wrapper: `Grep` and `GrepPattern`.

### `Sources/SwiftyShell/Brew/`

Typed wrapper for the Homebrew package manager: `Brew` and `BrewSubcommand`.

### `Sources/SwiftyShell/Swift/`

Typed wrapper for the Swift toolchain: `Swift`, `SwiftSubcommand`, and `SwiftBuildConfiguration`.

### `Sources/SwiftyShell/Gh/`

Typed wrapper for the GitHub CLI: `Gh` and `GhSubcommand`.

### `Sources/SwiftyShell/Docker/`

Typed wrapper for the Docker CLI: `Docker`, `DockerSubcommand`, and `DockerBuildProgress`.

### `Sources/SwiftyShell/Make/`

Typed wrapper for Make build automation: `Make`.

### `Sources/SwiftyShell/Node/`

Typed wrapper for the Node.js runtime: `Node`.

### `Sources/SwiftyShell/Npm/`

Typed wrapper for the npm package manager: `Npm` and `NpmSubcommand`.

### `Sources/SwiftyShell/Yarn/`

Typed wrapper for the Yarn package manager: `Yarn` and `YarnSubcommand`.

### `Sources/SwiftyShell/Pnpm/`

Typed wrapper for the pnpm package manager: `Pnpm` and `PnpmSubcommand`.

### `Sources/SwiftyShell/Bun/`

Typed wrapper for the Bun runtime and package manager: `Bun` and `BunSubcommand`.

### `Sources/SwiftyShell/Terraform/`

Typed wrapper for the Terraform CLI: `Terraform` and `TerraformSubcommand`.

### `Sources/SwiftyShell/Kubectl/`

Typed wrapper for the Kubernetes CLI: `Kubectl` and `KubectlSubcommand`.

### `Sources/SwiftyShell/Python/`

Typed wrapper for the Python interpreter CLI: `Python`.

### `Sources/SwiftyShell/Curl/`

Typed CLI-compatible HTTP transfer wrapper for curl: `Curl` and `CurlHTTPMethod`. Use it for shell
pipelines, CI recipes, artifact transfer, and vendor-provided curl commands; prefer `URLSession` for
ordinary in-process Swift API clients. Sensitive headers should be supplied via permission-restricted
files with `headerFile(_:)`, not argv-visible header values.

### `Sources/SwiftyShell/Common/`

Typed wrappers for frequently used shell utilities: `Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Jq`, `JqArgument`, `Rsync`, `Tar`, `TarOperation`, `TarCompression`, `Zip`, `ZipCompressionLevel`, `Unzip`, and `UnzipEntry`. Each follows the same fluent builder conventions as all other command families.

### `Sources/SwiftyShell/Internal/Execution/`

`SubprocessExecutor` — the real process execution engine backed by `swift-subprocess`. `public` because it is the default for `ShellContext.init`. The `Internal/` folder is organizational only.

### `Sources/SwiftyShell/SwiftyShell.docc/`

DocC documentation catalog. `SwiftyShell.md` is the top-level landing page. Articles live under `Articles/`:

- `GettingStarted.md` — installation, first command, pipelines, testing
- `SelectingCommandFamilies.md` — package trait reference and recipes
- `BuildingCommandFamilies.md` — how to author a new typed command family

### `Tests/SwiftyShellTests/`

Test suite. Sub-folders mirror the source layout: `Brew/`, `Bun/`, `Common/`, `Core/`, `Curl/`, `Docker/`, `Fzf/`, `Gh/`, `Git/`, `Grep/`, `Kubectl/`, `Make/`, `Node/`, `Npm/`, `Pipelines/`, `Pnpm/`, `Python/`, `Rg/`, `Swift/`, `Terraform/`, and `Yarn/`. Test files for gated families are wrapped in `#if <Trait>` so the test target compiles under any trait selection. `Common/` has one test file per family (`LsTests.swift`, `CpTests.swift`, …) plus `CommonTestSupport.swift` (shared helpers, ungated).

### `Scripts/`

`validate-traits.swift` — single-file Swift script that enforces the trait wiring contract: every gated source/test file is wrapped in the matching `#if <Trait>`, every family directory has a corresponding trait declaration in `Package.swift`, and the `All` umbrella transitively enables every per-family trait. CI runs this before any build job; run it locally with `swift -warnings-as-errors Scripts/validate-traits.swift`.

`validate-docc-coverage.swift` — single-file Swift script that enforces authored DocC coverage: every public top-level symbol must be linked from the DocC catalog, and every public command family must have user-facing DocC with Swift examples and a topics section. CI runs this before build/test jobs; run it locally with `swift -warnings-as-errors Scripts/validate-docc-coverage.swift`.

### `Example/`

A standalone SwiftPM executable package that demonstrates real SwiftyShell usage. Depends on SwiftyShell via a local path reference.

### `.claude/skills/`

`swiftyshell.md` — the shared SwiftyShell agent skill for Claude and Codex/GPT-style assistants. Claude loads it directly from `.claude/skills/swiftyshell.md`; Codex/GPT agents should read that same file when a task involves generating SwiftyShell code, changing public API, or authoring command families. **Keep `AGENTS.md` and `.claude/skills/swiftyshell.md` aligned and update both files in the same PR whenever shared agent guidance or public API expectations change.**

### `.codex/skills/`

`swiftyshell.md` — a **symlink** that resolves to `.claude/skills/swiftyshell.md`. There is only one file on disk; both paths serve the same content. Do not replace the symlink with a copy or fork the content here. To update skill content, edit `.claude/skills/swiftyshell.md` directly.

## Build and Test Commands

```bash
# Build
swift build -c release -Xswiftc -warnings-as-errors

# Run all tests
swift test -Xswiftc -warnings-as-errors

# Validate trait wiring and authored DocC coverage
swift -warnings-as-errors Scripts/validate-traits.swift
swift -warnings-as-errors Scripts/validate-docc-coverage.swift

# Build for release
swift build -c release -Xswiftc -warnings-as-errors

# Run a single test file by class name
swift test --filter CommandTests

# Format (in place) and lint Swift sources
swift-format format -i <file(s)>
swift-format lint --strict --recursive <path(s)>
```

## Definition of Done — HARD GATE

Do not mark a task complete, declare work finished, or hand back to the user until both of the following pass on every file you added or modified:

1. `swift test -Xswiftc -warnings-as-errors` — all tests green.
2. `swift-format lint --strict` — no errors on Swift files you touched. If you just wrote new Swift, run `swift-format format -i <file>` first so auto-fixable issues are corrected, then re-lint to confirm. Do not run `swift-format` on DocC Markdown; validate `.docc/*.md` changes with DocC coverage and generation instead.
3. `swift -warnings-as-errors Scripts/validate-traits.swift` — package trait wiring remains valid.
4. `swift -warnings-as-errors Scripts/validate-docc-coverage.swift` — authored DocC coverage remains valid.
5. `swift package -Xswiftc -warnings-as-errors --allow-writing-to-directory docs generate-documentation --target SwiftyShell --output-path docs --transform-for-static-hosting --hosting-base-path SwiftyShell` — DocC builds cleanly when public API or DocC content changes.
6. `swift test --enable-all-traits --enable-code-coverage -Xswiftc -warnings-as-errors` and `swift -warnings-as-errors Scripts/validate-code-coverage.swift --input <codecov-path> --minimum-line-coverage 84` — the coverage gate remains valid.

This applies to any code change (new command families, bug fixes, doc snippets that live in Swift, tests). Do not skip either gate. If a lint rule feels wrong for a specific construct, propose a `.swift-format` change in the same PR rather than bypassing the check.

The repository ships a `.swift-format` config at the repo root that encodes the project's 4-space indentation, 120-column line length, and other style rules. The tree is currently fully compliant — `swift-format lint --strict --recursive Sources Tests Scripts` exits clean, and CI runs the same command on every push. Keep it that way. `swift-format` parses inputs as Swift source, so Markdown-only documentation changes should use the DocC validation gates rather than direct Markdown linting with `swift-format`.

## Key Conventions

### Public API Design

- All public types are value types (`struct`) conforming to `Sendable`
- Fluent builder pattern: every mutating method returns a new `Self` copy
- `init(context: ShellContext = .init())` is the standard entry point for typed clients
- Every typed client exposes `executable(_:)`, `env(_:_:)`, `workingDirectory(_:)`, `timeout(_:)`, `outputLimit(_:)`, `command() -> Command`, and `run() async throws`; clients conforming to `RunnableCommandFamily` also inherit `spawn(teardown:) async throws`
- `ShellContext` is infrastructure, not a command namespace — `Command("pwd")` not `context.pwd()`

### Documentation — MANDATORY

**Every public declaration must have a `///` doc comment. No exceptions.**

This applies to:
- `public struct`, `public class`, `public enum`, `public protocol`
- `public var`, `public let` (properties)
- `public func`, `public init`
- `public typealias`
- `public case` on enums

**Rules:**
1. Type-level docs explain what the type _is_ and when to use it
2. Method-level docs explain what the method _does_ and note any non-obvious behavior
3. Parameter docs (`- Parameter name:`) for non-trivial parameters
4. Use ``SymbolName`` double-backtick links to cross-reference related types
5. Include a code example in the type-level doc for all types that are primary API surface

**When you add or modify any public declaration, write or update its doc comment in the same change. Do not leave undocumented public API.**

**When you add or modify any public code, command family, command method, workflow, parser result, or reusable behavior, update authored DocC in `Sources/SwiftyShell/SwiftyShell.docc/` in the same change.** Doc comments alone are not enough. New public symbols must be discoverable from DocC pages, and every public command family must have user-facing DocC with realistic Swift examples and a `## Topics` section.

Verify your work: after editing, scan the file for `public ` lines without a preceding `///` line.

### Error Handling

All failures surface as `ShellError`. Never throw raw `Error` or `NSError` from public code. Use `ShellError.spawnError` for unexpected process launch failures.

### Execution Engine

`SubprocessExecutor` (in `Internal/Execution/`) is `public` because `ShellContext.init` defaults to it. The `Internal/` folder label is organizational — it does not imply the type is hidden from callers.

The production executor uses the `swift-subprocess` package for process lifecycle management. Keep SwiftyShell's public error semantics stable when changing it: map process failures into `ShellError`, preserve partial output on timeout/output-limit/cancellation paths, and keep `MockExecutor` behavior aligned with production where practical.

### Workflows

`Workflow<Value>` is single-use — `run()` consumes it. Typed workflow types (`GitStatusWorkflow`) queue steps until `run()` is awaited. Never call `run()` more than once on the same workflow instance.

### Testing

Use `MockExecutor` for unit tests. It implements `CommandExecutor`, mirrors real `run()` failure semantics for non-zero exits, validates timeout/output-limit configuration, and returns caller-supplied responses without spawning processes. Its `spawn` support returns `MockSpawnedProcess`, which records signals, teardown, and the configured `TeardownStrategy` so spawned-process code can be tested without launching a subprocess. Integration tests that require real executables should be clearly annotated.

### Agent Skill

`.claude/skills/swiftyshell.md` is the canonical shared skill for all agents working in this repo, including Claude and Codex/GPT assistants. `.codex/skills/swiftyshell.md` is only a pointer to that canonical file. When a task involves generating SwiftyShell code, changing public API, or adding command families, read the shared skill in addition to this guide. Keep `AGENTS.md` and `.claude/skills/swiftyshell.md` aligned and update both in the same PR whenever shared guidance or public API expectations change. The skill must reflect the implemented API, not the spec.

### Package Traits

SwiftyShell uses [SwiftPM Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) so each typed command family is opt-in. The default trait set is **empty** — only `Core/` and `Internal/` types compile by default. Consumers select families via `traits:` on `.package(...)`.

**Trait inventory (declared in `Package.swift`):**

- Per-family: `Git`, `Brew`, `Grep`, `Fzf`, `Rg`, `Swift`, `Gh`, `Docker`, `Make`, `Node`, `Npm`, `Yarn`, `Pnpm`, `Bun`, `Terraform`, `Kubectl`, `Python`, `Curl`, `Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Jq`, `Rsync`, `Tar`, `Zip`, `Unzip` (one trait per family directory; for `Common/`, one trait per file).
- Umbrellas: `CommonUtilities` (all `Common/*`), `All` (every family).

**The wiring contract** — enforced by `Scripts/validate-traits.swift` and CI:

1. Every `.swift` file under a gated source directory (`Git/`, `Brew/`, `Grep/`, `Fzf/`, `Rg/`, `Swift/`, `Gh/`, `Docker/`, `Make/`, `Node/`, `Npm/`, `Yarn/`, `Pnpm/`, `Bun/`, `Terraform/`, `Kubectl/`, `Python/`, `Curl/`, and each file in `Common/`) is wrapped top-to-bottom in `#if <Trait> ... #endif`.
2. Every test file targeting a gated family is wrapped the same way. Cross-family tests use combined guards (`#if Git && Grep`).
3. Every family directory (or `Common/*.swift` file) has a matching `.trait(name:)` entry in `Package.swift`.
4. The `All` umbrella's `enabledTraits` transitively enables every per-family trait. The `CommonUtilities` umbrella enables every `Common/*` trait.
5. `Core/` and `Internal/` files are **never** gated.

**When you add a new command family:**

1. Add the directory or file under `Sources/SwiftyShell/<Family>/` (or `Sources/SwiftyShell/Common/<Family>.swift`).
2. Wrap every source file in `#if <Family> ... #endif`.
3. Add the matching `.trait(name: "<Family>", description: "...")` in `Package.swift`.
4. Add `<Family>` to the `All` umbrella's `enabledTraits` (and `CommonUtilities` if it's a `Common/*` family).
5. Add tests under `Tests/SwiftyShellTests/<Family>/` (or `Tests/SwiftyShellTests/Common/<Family>Tests.swift`) and wrap them in `#if <Family>`.
6. Run `swift -warnings-as-errors Scripts/validate-traits.swift` to confirm the wiring is correct.
7. Verify with `swift build --traits <Family> -Xswiftc -warnings-as-errors` and `swift test --traits <Family> -Xswiftc -warnings-as-errors` in addition to the default and `--enable-all-traits` runs.

If the new command family has real execution tests that depend on an external CLI binary not guaranteed by the GitHub Actions runner image, update `.github/workflows/reusable-ci.yml` in the same change to install that tool for every affected matrix entry (the family trait itself, `All`, and coverage runs that use `--enable-all-traits`). Keep the Linux package install and macOS Homebrew install paths in sync.

The pull-request template (`.github/PULL_REQUEST_TEMPLATE.md`) has a checklist that mirrors these steps. CI runs `validate-traits` first and then a build/test matrix across `""`, each per-family trait, `CommonUtilities`, and `All` on macOS 15 and Linux. A new family that bypasses the wiring will fail validation before any build runs.

## Architecture Reference

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the design rationale, execution model, type-safety philosophy, and deferred roadmap.
