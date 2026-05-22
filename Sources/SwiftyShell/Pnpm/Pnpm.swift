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
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a pnpm command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects a pnpm subcommand.
    public func subcommand(_ value: PnpmSubcommand) -> Self { copy(subcommand: value.rawValue, scriptName: nil) }

    /// Returns a copy that selects a raw pnpm subcommand.
    public func subcommand(_ value: String) -> Self { copy(subcommand: value, scriptName: nil) }

    /// Returns a copy configured for `pnpm install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `pnpm add <packages>`.
    public func add(_ packages: String...) -> Self { add(packages) }

    /// Returns a copy configured for `pnpm add <packages>`.
    public func add(_ packages: [String]) -> Self { copy(subcommand: "add", scriptName: nil, positionals: packages) }

    /// Returns a copy configured for `pnpm remove <packages>`.
    public func remove(_ packages: String...) -> Self { remove(packages) }

    /// Returns a copy configured for `pnpm remove <packages>`.
    public func remove(_ packages: [String]) -> Self {
        copy(subcommand: "remove", scriptName: nil, positionals: packages)
    }

    /// Returns a copy configured for `pnpm test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `pnpm exec <binary>`.
    public func exec(_ binary: String? = nil) -> Self {
        copy(subcommand: "exec", scriptName: nil, positionals: binary.map { [$0] } ?? [])
    }

    /// Returns a copy configured for `pnpm dlx <package>`.
    public func dlx(_ package: String? = nil) -> Self {
        copy(subcommand: "dlx", scriptName: nil, positionals: package.map { [$0] } ?? [])
    }

    /// Returns a copy configured for `pnpm run <name>`.
    public func runScript(_ name: String) -> Self { copy(subcommand: "run", scriptName: name, positionals: []) }

    /// Returns a copy that passes `--dir <path>`.
    public func directory(_ path: String) -> Self { copy(directoryPath: path) }

    /// Returns a copy that passes `--filter <selector>`.
    public func filter(_ selector: String) -> Self { copy(filters: state.filters + [selector]) }

    /// Returns a copy that passes `--recursive`.
    public func recursive(_ enabled: Bool = true) -> Self { copy(isRecursive: enabled) }

    /// Returns a copy that passes `--if-present`.
    public func ifPresent(_ enabled: Bool = true) -> Self { copy(ifPresentEnabled: enabled) }

    /// Returns a copy that passes `--frozen-lockfile`.
    public func frozenLockfile(_ enabled: Bool = true) -> Self { copy(usesFrozenLockfile: enabled) }

    /// Returns a copy that passes `--prod`.
    public func production(_ enabled: Bool = true) -> Self { copy(isProduction: enabled) }

    /// Returns a copy that passes `--json`.
    public func json(_ enabled: Bool = true) -> Self { copy(outputsJSON: enabled) }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a positional package, binary, or script argument.
    public func positionalArgument(_ value: String) -> Self { copy(positionals: state.positionals + [value]) }

    /// Returns a copy that appends positional package, binary, or script arguments.
    public func positionalArguments(_ values: [String]) -> Self { copy(positionals: state.positionals + values) }

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

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: String? = nil,
        scriptName: String?? = nil,
        directoryPath: String?? = nil,
        filters: [String]? = nil,
        isRecursive: Bool? = nil,
        ifPresentEnabled: Bool? = nil,
        usesFrozenLockfile: Bool? = nil,
        isProduction: Bool? = nil,
        outputsJSON: Bool? = nil,
        extraArguments: [String]? = nil,
        positionals: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                scriptName: scriptName ?? state.scriptName,
                directoryPath: directoryPath ?? state.directoryPath,
                filters: filters ?? state.filters,
                isRecursive: isRecursive ?? state.isRecursive,
                ifPresentEnabled: ifPresentEnabled ?? state.ifPresentEnabled,
                usesFrozenLockfile: usesFrozenLockfile ?? state.usesFrozenLockfile,
                isProduction: isProduction ?? state.isProduction,
                outputsJSON: outputsJSON ?? state.outputsJSON,
                extraArguments: extraArguments ?? state.extraArguments,
                positionals: positionals ?? state.positionals
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let subcommand: String
    let scriptName: String?
    let directoryPath: String?
    let filters: [String]
    let isRecursive: Bool
    let ifPresentEnabled: Bool
    let usesFrozenLockfile: Bool
    let isProduction: Bool
    let outputsJSON: Bool
    let extraArguments: [String]
    let positionals: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: String = "--version",
        scriptName: String? = nil,
        directoryPath: String? = nil,
        filters: [String] = [],
        isRecursive: Bool = false,
        ifPresentEnabled: Bool = false,
        usesFrozenLockfile: Bool = false,
        isProduction: Bool = false,
        outputsJSON: Bool = false,
        extraArguments: [String] = [],
        positionals: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.scriptName = scriptName
        self.directoryPath = directoryPath
        self.filters = filters
        self.isRecursive = isRecursive
        self.ifPresentEnabled = ifPresentEnabled
        self.usesFrozenLockfile = usesFrozenLockfile
        self.isProduction = isProduction
        self.outputsJSON = outputsJSON
        self.extraArguments = extraArguments
        self.positionals = positionals
    }
}
#endif
