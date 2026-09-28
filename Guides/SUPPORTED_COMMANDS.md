# Supported commands

Each typed command family is opt-in through a SwiftPM trait with the same name. Select only what your package uses, or choose `CommonUtilities` or `All` for an umbrella selection. The default trait set enables no typed families.

For the complete trait reference and recipes, see the DocC [Selecting Command Families guide](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/selectingcommandfamilies). Each family also has a dedicated DocC page with API details and examples.

| Swift family | Executable | Trait | Coverage |
|---|---|---|---|
| `Git` | `git` | `Git` | Status, branches, worktrees, submodules, diff, log, config, merge, commit, and rebase workflows |
| `Grep` | `grep` | `Grep` | Literal and regex patterns, recursive search, case handling |
| `Rg` | `rg` | `Rg` | ripgrep options, context, globs, and JSON output |
| `Fzf` | `fzf` | `Fzf` | Non-interactive filter-mode fuzzy finder pipelines |
| `Brew` | `brew` | `Brew` | Homebrew subcommands, cask and greedy options |
| `Swift` | `swift` | `Swift` | SwiftPM build, test, run, package, traits, and compiler flags |
| `Cargo` | `cargo` | `Cargo` | Rust build, test, check, run, format, Clippy, and package operations |
| `Gh` | `gh` | `Gh` | GitHub CLI PR, repository, workflow, Copilot, skills, and API operations |
| `Docker` | `docker` | `Docker` | Buildx, Compose, Debug, MCP, Scout, images, and containers |
| `Make` | `make` | `Make` | Makefile targets, parallel jobs, dry runs, and keep-going builds |
| `Node` | `node` | `Node` | Runtime scripts, eval, syntax checks, and script files |
| `Npm` | `npm` | `Npm` | Installs, scripts, package execution, and audits |
| `Yarn` | `yarn` | `Yarn` | Installs, scripts, package execution, and workspaces |
| `Pnpm` | `pnpm` | `Pnpm` | Installs, scripts, filters, and recursive workspace runs |
| `Bun` | `bun` | `Bun` | Runtime, package manager, tests, scripts, and builds |
| `Terraform` | `terraform` | `Terraform` | Init, plan, apply, workspaces, and outputs |
| `Kubectl` | `kubectl` | `Kubectl` | Get, apply, logs, exec, namespaces, and contexts |
| `Helm` | `helm` | `Helm` | Template, lint, install, upgrade, list, status, and uninstall |
| `Python` | `python3` | `Python` | Interpreter modules, command strings, scripts, and options |
| `Curl` | `curl` | `Curl` | CLI-compatible HTTP transfers for pipelines, CI, and artifacts |
| `Ls` | `ls` | `Ls` | Listing, flags, recursion, and human-readable sizes |
| `Cp` | `cp` | `Cp` | Copying, recursive and force modes |
| `Mkdir` | `mkdir` | `Mkdir` | Directory creation, parent directories, and permissions |
| `Chmod` | `chmod` | `Chmod` | Recursive permission updates |
| `Rm` | `rm` | `Rm` | Removal, recursive and force modes |
| `Mv` | `mv` | `Mv` | Moving and force mode |
| `Pwd` | `pwd` | `Pwd` | Physical and logical paths |
| `Jq` | `jq` | `Jq` | Filter expressions, `--arg` bindings, and raw output |
| `Rsync` | `rsync` | `Rsync` | Archive/recursive sync, filters, remote shell, deletion, and dry runs |
| `Tar` | `tar` | `Tar` | Portable archive creation, extraction, listing, and compression |
| `Zip` | `zip` | `Zip` | Info-ZIP creation, compression, recursion, and exclusions |
| `Unzip` | `unzip` | `Unzip` | Info-ZIP extraction and structured entry listing |
| `Ln` | `ln` | `Ln` | Hard and symbolic links |
| `Touch` | `touch` | `Touch` | File creation and timestamp controls |
| `Env` | `env` | `Env` | Set or clear environment and invoke commands without a shell |
| `Which` | `which` | `Which` | Typed found/not-found executable lookup |
| `Find` | `find` | `Find` | Portable predicates, boolean expressions, and safe path output |

## Choose traits

```swift
.package(
    url: "https://github.com/maniramezan/SwiftyShell.git",
    from: "0.3.0",
    traits: ["Git", "Grep", "Fzf"]
)
```

`CommonUtilities` enables `Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Jq`, `Rsync`, `Tar`, `Zip`, `Unzip`, `Ln`, `Touch`, `Env`, `Which`, and `Find`. `All` enables every family.

## Run an unlisted executable

Use the core `Command` API for a tool without a typed family:

```swift
let output = try await Command("my-tool", arguments: "--flag", "value").run()
```

If you use a tool often, the DocC [Building Command Families guide](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/buildingcommandfamilies) explains how to add a typed wrapper.
