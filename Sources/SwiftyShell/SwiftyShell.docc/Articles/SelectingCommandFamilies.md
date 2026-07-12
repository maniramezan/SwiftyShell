# Selecting Command Families

Pick exactly the typed shell wrappers your project needs.

## Overview

SwiftyShell is split into a small, always-available `Core` (commands,
pipelines, contexts, errors, executors) and a set of **opt-in** typed
command families: ``Git``, ``Brew``, ``Grep``, ``Fzf``, ``Rg``, ``Swift``, ``Gh``, ``Docker``, ``Make``, ``Node``, ``Npm``,
``Yarn``, ``Pnpm``, ``Bun``, ``Terraform``, ``Kubectl``, ``Helm``, ``Python``, ``Curl``, and a collection of common
file/directory utilities (``Ls``, ``Cp``, ``Mv``, ``Mkdir``, ``Chmod``, ``Rm``, ``Pwd``,
``Jq``, ``Rsync``, ``Tar``, ``Zip``, ``Unzip``, ``Ln``, ``Touch``, ``Env``, ``Which``).

Each family is gated behind a SwiftPM **package trait**. By default no
families are enabled, so a fresh `import SwiftyShell` exposes only `Core`.
Consumers opt into families they need from their own `Package.swift`. This
keeps build size, compile time, and surface area honest as the library grows.

## Quick start

Enable a single family — Git in this example — by passing it through
`traits:` on the dependency:

```swift
.package(
    url: "https://github.com/maniramezan/SwiftyShell.git",
    from: "0.3.0",
    traits: ["Git"]
)
```

Now ``Git`` is available alongside everything in `Core`:

```swift
import SwiftyShell

let status = try await Git()
    .workingDirectory("/path/to/repo")
    .status()
    .run()
```

## Available traits

| Trait              | Enables                                                    |
|--------------------|------------------------------------------------------------|
| `Git`              | ``Git`` including status, branch, log, diff, config, and submodule wrappers |
| `Brew`             | ``Brew`` Homebrew wrapper                                  |
| `Grep`             | ``Grep`` typed grep wrapper                                |
| `Fzf`              | ``Fzf`` typed fuzzy-finder wrapper                         |
| `Rg`               | ``Rg`` typed ripgrep wrapper                               |
| `Swift`            | ``Swift`` Swift toolchain and SwiftPM wrapper              |
| `Gh`               | ``Gh`` GitHub CLI automation wrapper                       |
| `Docker`           | ``Docker`` Docker CLI automation wrapper                   |
| `Make`             | ``Make`` build automation wrapper                          |
| `Node`             | ``Node`` Node.js runtime wrapper                           |
| `Npm`              | ``Npm`` package manager and script runner wrapper          |
| `Yarn`             | ``Yarn`` package manager and script runner wrapper         |
| `Pnpm`             | ``Pnpm`` package manager and workspace script runner wrapper |
| `Bun`              | ``Bun`` runtime, bundler, and package manager wrapper      |
| `Terraform`        | ``Terraform`` infrastructure automation wrapper            |
| `Kubectl`          | ``Kubectl`` Kubernetes CLI automation wrapper              |
| `Helm`             | ``Helm`` operation-specific Kubernetes package manager wrapper |
| `Python`           | ``Python`` interpreter and script runner wrapper           |
| `Curl`             | ``Curl`` typed HTTP request and transfer wrapper            |
| `Ls`               | ``Ls``                                                     |
| `Cp`               | ``Cp``                                                     |
| `Mv`               | ``Mv``                                                     |
| `Mkdir`            | ``Mkdir``                                                  |
| `Chmod`            | ``Chmod``                                                  |
| `Rm`               | ``Rm``                                                     |
| `Pwd`              | ``Pwd``                                                    |
| `Jq`               | ``Jq``                                                     |
| `Rsync`            | ``Rsync`` file synchronization wrapper                     |
| `Tar`              | ``Tar`` portable archive creation, extraction, and listing |
| `Zip`              | ``Zip`` Info-ZIP archive creation wrapper                  |
| `Unzip`            | ``Unzip`` Info-ZIP archive extraction and listing wrapper  |
| `Ln`               | ``Ln`` hard and symbolic link wrapper                       |
| `Touch`            | ``Touch`` file creation and timestamp wrapper               |
| `Env`              | ``Env`` environment and safe command invocation wrapper     |
| `Which`            | ``Which`` typed executable lookup                           |
| `CommonUtilities`  | Every common utility family listed above                    |
| `All`              | Every per-family trait above (the kitchen-sink umbrella)   |

## Common recipes

### A project that needs Git, grep, and fzf

```swift
.package(
    url: "https://github.com/maniramezan/SwiftyShell.git",
    from: "0.3.0",
    traits: ["Git", "Grep", "Fzf"]
)
```

### A project that wants every common file utility

```swift
.package(
    url: "https://github.com/maniramezan/SwiftyShell.git",
    from: "0.3.0",
    traits: ["CommonUtilities"]
)
```

### Everything, for tooling, exploration, or scripts

```swift
.package(
    url: "https://github.com/maniramezan/SwiftyShell.git",
    from: "0.3.0",
    traits: ["All"]
)
```

> Tip: Even when no family trait is enabled, you can still drive arbitrary
> shell commands with ``Command`` and ``Pipeline`` from `Core`. The typed
> families are purely a quality-of-life layer on top.

## Why opt-in

Trait-based selection lets the package add many more typed families over
time without growing every consumer's binary or compile time. The traits
form a public contract that contributors must keep honest: the
`Scripts/validate-traits.swift` script and the per-trait CI matrix fail any
change that introduces hidden coupling between families.

## Working in Xcode and other tooling

Most IDEs (Xcode, VS Code with sourcekit-lsp) inherit traits from the
consuming package's `Package.swift`. When invoking SwiftPM directly you can
pass `--traits Git,Grep,Fzf` (or `--enable-all-traits` for everything) to mirror
the consumer build:

```sh
swift build -c release -Xswiftc -warnings-as-errors --traits Git
swift test  -Xswiftc -warnings-as-errors --traits Git,Grep,Fzf
swift test  -Xswiftc -warnings-as-errors --enable-all-traits
```

## See also

- ``Command``
- ``Pipeline``
- ``ShellContext``
- <doc:BuildingCommandFamilies>
