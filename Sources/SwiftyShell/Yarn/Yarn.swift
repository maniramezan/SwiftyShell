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
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Yarn command family bound to a shell context.
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

    /// Returns a copy that selects a Yarn subcommand.
    public func subcommand(_ value: YarnSubcommand) -> Self { copy(subcommand: value.rawValue, scriptName: nil) }

    /// Returns a copy that selects a raw Yarn subcommand.
    public func subcommand(_ value: String) -> Self { copy(subcommand: value, scriptName: nil) }

    /// Returns a copy configured for `yarn install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `yarn add <packages>`.
    public func add(_ packages: String...) -> Self { add(packages) }

    /// Returns a copy configured for `yarn add <packages>`.
    public func add(_ packages: [String]) -> Self { copy(subcommand: "add", scriptName: nil, positionals: packages) }

    /// Returns a copy configured for `yarn remove <packages>`.
    public func remove(_ packages: String...) -> Self { remove(packages) }

    /// Returns a copy configured for `yarn remove <packages>`.
    public func remove(_ packages: [String]) -> Self {
        copy(subcommand: "remove", scriptName: nil, positionals: packages)
    }

    /// Returns a copy configured for `yarn test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `yarn exec <binary>`.
    public func exec(_ binary: String? = nil) -> Self {
        copy(subcommand: "exec", scriptName: nil, positionals: binary.map { [$0] } ?? [])
    }

    /// Returns a copy configured for `yarn dlx <package>`.
    public func dlx(_ package: String? = nil) -> Self {
        copy(subcommand: "dlx", scriptName: nil, positionals: package.map { [$0] } ?? [])
    }

    /// Returns a copy configured for `yarn run <name>`.
    public func runScript(_ name: String) -> Self { copy(subcommand: "run", scriptName: name, positionals: []) }

    /// Returns a copy that passes `--cwd <path>`.
    public func cwd(_ path: String) -> Self { copy(cwdPath: path) }

    /// Returns a copy that passes `--immutable`.
    public func immutable(_ enabled: Bool = true) -> Self { copy(isImmutable: enabled) }

    /// Returns a copy that passes `--production`.
    public func production(_ enabled: Bool = true) -> Self { copy(isProduction: enabled) }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { copy(isSilent: enabled) }

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

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: String? = nil,
        scriptName: String?? = nil,
        cwdPath: String?? = nil,
        isImmutable: Bool? = nil,
        isProduction: Bool? = nil,
        isSilent: Bool? = nil,
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
                cwdPath: cwdPath ?? state.cwdPath,
                isImmutable: isImmutable ?? state.isImmutable,
                isProduction: isProduction ?? state.isProduction,
                isSilent: isSilent ?? state.isSilent,
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
    let cwdPath: String?
    let isImmutable: Bool
    let isProduction: Bool
    let isSilent: Bool
    let outputsJSON: Bool
    let extraArguments: [String]
    let positionals: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: String = "--version",
        scriptName: String? = nil,
        cwdPath: String? = nil,
        isImmutable: Bool = false,
        isProduction: Bool = false,
        isSilent: Bool = false,
        outputsJSON: Bool = false,
        extraArguments: [String] = [],
        positionals: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.scriptName = scriptName
        self.cwdPath = cwdPath
        self.isImmutable = isImmutable
        self.isProduction = isProduction
        self.isSilent = isSilent
        self.outputsJSON = outputsJSON
        self.extraArguments = extraArguments
        self.positionals = positionals
    }
}

private func appendOption(_ name: String, _ value: String?, to arguments: inout [String]) {
    if let value { arguments += [name, value] }
}
#endif
