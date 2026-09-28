#if Yarn
import Foundation

/// The top-level Yarn command to invoke.
public enum YarnSubcommand: String, Sendable, Equatable, Hashable {
    /// `yarn install` — install project dependencies.
    case install
    /// `yarn add` — add dependencies to a project.
    case add
    /// `yarn remove` — remove dependencies from a project.
    case remove
    /// `yarn run` — run a package script or binary.
    case run
    /// `yarn test` — run the package test script.
    case test
    /// `yarn exec` — execute a command in the project environment.
    case exec
    /// `yarn dlx` — run a package in a temporary environment.
    case dlx
    /// `yarn workspaces` — run workspace-level commands.
    case workspaces
    /// `yarn version` — manage project versions.
    case version
}

/// A fluent wrapper for the Yarn package manager CLI.
///
/// ``Yarn`` covers common dependency installation, script execution, and
/// workspace automation while still allowing raw options and positional
/// arguments for less common subcommands.
///
/// ```swift
/// try await Yarn()
///     .runScript("build")
///     .immutable()
///     .run()
/// ```
public struct Yarn: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Yarn command family bound to a shell context.
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

    /// Returns a copy that selects a Yarn subcommand.
    public func subcommand(_ value: YarnSubcommand) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.scriptName = nil
        }
    }

    /// Returns a copy that selects a raw Yarn subcommand.
    public func subcommand(_ value: String) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.scriptName = nil
        }
    }

    /// Returns a copy configured for `yarn install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `yarn add <packages>`.
    public func add(_ packages: String...) -> Self { add(packages) }

    /// Returns a copy configured for `yarn add <packages>`.
    public func add(_ packages: [String]) -> Self {
        modified(self) {
            $0.state.subcommand = "add"
            $0.state.scriptName = nil
            $0.state.positionals = packages
        }
    }

    /// Returns a copy configured for `yarn remove <packages>`.
    public func remove(_ packages: String...) -> Self { remove(packages) }

    /// Returns a copy configured for `yarn remove <packages>`.
    public func remove(_ packages: [String]) -> Self {
        modified(self) {
            $0.state.subcommand = "remove"
            $0.state.scriptName = nil
            $0.state.positionals = packages
        }
    }

    /// Returns a copy configured for `yarn test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `yarn exec <binary>`.
    public func exec(_ binary: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = "exec"
            $0.state.scriptName = nil
            $0.state.positionals = binary.map { [$0] } ?? []
        }
    }

    /// Returns a copy configured for `yarn dlx <package>`.
    public func dlx(_ package: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = "dlx"
            $0.state.scriptName = nil
            $0.state.positionals = package.map { [$0] } ?? []
        }
    }

    /// Returns a copy configured for `yarn run <name>`.
    public func runScript(_ name: String) -> Self {
        modified(self) {
            $0.state.subcommand = "run"
            $0.state.scriptName = name
            $0.state.positionals = []
        }
    }

    /// Returns a copy that passes `--cwd <path>`.
    public func cwd(_ path: String) -> Self { modified(self) { $0.state.cwdPath = path } }

    /// Returns a copy that passes `--immutable`.
    public func immutable(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isImmutable = enabled } }

    /// Returns a copy that passes `--production`.
    public func production(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isProduction = enabled } }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isSilent = enabled } }

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

    /// Builds the raw `yarn` command represented by the current builder state.
    public func command() -> Command {
        var arguments = [state.subcommand]
        appendOption("--cwd", state.cwdPath, to: &arguments)
        if state.isImmutable { arguments.append("--immutable") }
        if state.isProduction { arguments.append("--production") }
        if state.isSilent { arguments.append("--silent") }
        if state.outputsJSON { arguments.append("--json") }
        arguments += state.extraArguments
        if let scriptName = state.scriptName { arguments.append(scriptName) }
        arguments += state.positionals

        let base = Command("yarn").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var subcommand: String = "--version"
    var scriptName: String? = nil
    var cwdPath: String? = nil
    var isImmutable: Bool = false
    var isProduction: Bool = false
    var isSilent: Bool = false
    var outputsJSON: Bool = false
    var extraArguments: [String] = []
    var positionals: [String] = []
}
#endif
