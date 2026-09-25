#if Pnpm
import Foundation

/// The top-level pnpm command to invoke.
public enum PnpmSubcommand: String, Sendable, Equatable, Hashable {
    /// `pnpm install` — install project dependencies.
    case install
    /// `pnpm add` — add dependencies to a project.
    case add
    /// `pnpm remove` — remove dependencies from a project.
    case remove
    /// `pnpm run` — run a package script.
    case run
    /// `pnpm test` — run the package test script.
    case test
    /// `pnpm exec` — execute a package binary.
    case exec
    /// `pnpm dlx` — run a package in a temporary environment.
    case dlx
    /// `pnpm audit` — audit dependency vulnerabilities.
    case audit
    /// `pnpm version` — manage project versions.
    case version
}

/// A fluent wrapper for the pnpm package manager CLI.
///
/// ``Pnpm`` focuses on deterministic installs, workspace script execution,
/// filtering, and package binary execution.
///
/// ```swift
/// try await Pnpm()
///     .runScript("build")
///     .recursive()
///     .filter("./packages/app")
///     .run()
/// ```
public struct Pnpm: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a pnpm command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that selects a pnpm subcommand.
    public func subcommand(_ value: PnpmSubcommand) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.scriptName = nil
        }
    }

    /// Returns a copy that selects a raw pnpm subcommand.
    public func subcommand(_ value: String) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.scriptName = nil
        }
    }

    /// Returns a copy configured for `pnpm install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `pnpm add <packages>`.
    public func add(_ packages: String...) -> Self { add(packages) }

    /// Returns a copy configured for `pnpm add <packages>`.
    public func add(_ packages: [String]) -> Self {
        modified(self) {
            $0.state.subcommand = "add"
            $0.state.scriptName = nil
            $0.state.positionals = packages
        }
    }

    /// Returns a copy configured for `pnpm remove <packages>`.
    public func remove(_ packages: String...) -> Self { remove(packages) }

    /// Returns a copy configured for `pnpm remove <packages>`.
    public func remove(_ packages: [String]) -> Self {
        modified(self) {
            $0.state.subcommand = "remove"
            $0.state.scriptName = nil
            $0.state.positionals = packages
        }
    }

    /// Returns a copy configured for `pnpm test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `pnpm exec <binary>`.
    public func exec(_ binary: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = "exec"
            $0.state.scriptName = nil
            $0.state.positionals = binary.map { [$0] } ?? []
        }
    }

    /// Returns a copy configured for `pnpm dlx <package>`.
    public func dlx(_ package: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = "dlx"
            $0.state.scriptName = nil
            $0.state.positionals = package.map { [$0] } ?? []
        }
    }

    /// Returns a copy configured for `pnpm run <name>`.
    public func runScript(_ name: String) -> Self {
        modified(self) {
            $0.state.subcommand = "run"
            $0.state.scriptName = name
            $0.state.positionals = []
        }
    }

    /// Returns a copy that passes `--dir <path>`.
    public func directory(_ path: String) -> Self { modified(self) { $0.state.directoryPath = path } }

    /// Returns a copy that passes `--filter <selector>`.
    public func filter(_ selector: String) -> Self { modified(self) { $0.state.filters += [selector] } }

    /// Returns a copy that passes `--recursive`.
    public func recursive(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isRecursive = enabled } }

    /// Returns a copy that passes `--if-present`.
    public func ifPresent(_ enabled: Bool = true) -> Self { modified(self) { $0.state.ifPresentEnabled = enabled } }

    /// Returns a copy that passes `--frozen-lockfile`.
    public func frozenLockfile(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesFrozenLockfile = enabled }
    }

    /// Returns a copy that passes `--prod`.
    public func production(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isProduction = enabled } }

    /// Returns a copy that passes `--json`.
    public func json(_ enabled: Bool = true) -> Self { modified(self) { $0.state.outputsJSON = enabled } }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends a positional package, binary, or script argument.
    public func positionalArgument(_ value: String) -> Self { modified(self) { $0.state.positionals += [value] } }

    /// Returns a copy that appends positional package, binary, or script arguments.
    public func positionalArguments(_ values: [String]) -> Self { modified(self) { $0.state.positionals += values } }

    /// Builds the raw `pnpm` command represented by the current builder state.
    public func command() -> Command {
        var arguments = [state.subcommand]
        appendOption("--dir", state.directoryPath, to: &arguments)
        if state.isRecursive { arguments.append("--recursive") }
        for filter in state.filters { arguments += ["--filter", filter] }
        if state.ifPresentEnabled { arguments.append("--if-present") }
        if state.usesFrozenLockfile { arguments.append("--frozen-lockfile") }
        if state.isProduction { arguments.append("--prod") }
        if state.outputsJSON { arguments.append("--json") }
        arguments += state.extraArguments
        if let scriptName = state.scriptName { arguments.append(scriptName) }
        arguments += state.positionals

        let base = Command("pnpm").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var subcommand: String = "--version"
    var scriptName: String? = nil
    var directoryPath: String? = nil
    var filters: [String] = []
    var isRecursive: Bool = false
    var ifPresentEnabled: Bool = false
    var usesFrozenLockfile: Bool = false
    var isProduction: Bool = false
    var outputsJSON: Bool = false
    var extraArguments: [String] = []
    var positionals: [String] = []
}
#endif
