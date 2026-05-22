#if Node
import Foundation

/// A fluent wrapper for the Node.js runtime CLI (`node`).
///
/// ``Node`` covers common scripting entry points: version checks, inline code
/// evaluation, syntax checks, preload modules, and script execution.
///
/// ```swift
/// let output = try await Node()
///     .eval("console.log(process.version)")
///     .run()
/// ```
public struct Node: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Node command family bound to a shell context.
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

    /// Returns a copy that prints Node.js version information with `--version`.
    public func version() -> Self { copy(mode: .version, scriptArguments: []) }

    /// Returns a copy that evaluates JavaScript with `--eval <code>`.
    public func eval(_ code: String) -> Self { copy(mode: .eval(code), scriptArguments: []) }

    /// Returns a copy that prints JavaScript expression output with `--print <code>`.
    public func printExpression(_ code: String) -> Self { copy(mode: .print(code), scriptArguments: []) }

    /// Returns a copy that checks a script's syntax with `--check <path>`.
    public func check(_ path: String) -> Self { copy(mode: .check(path), scriptArguments: []) }

    /// Returns a copy that runs a JavaScript file.
    public func script(_ path: String) -> Self { copy(mode: .script(path), scriptArguments: []) }

    /// Returns a copy that preloads a module with `--require <module>`.
    public func require(_ module: String) -> Self { copy(requires: state.requires + [module]) }

    /// Returns a copy that enables inspector support with `--inspect`.
    public func inspect(_ enabled: Bool = true) -> Self { copy(inspects: enabled) }

    /// Returns a copy that enables watch mode with `--watch`.
    public func watch(_ enabled: Bool = true) -> Self { copy(watches: enabled) }

    /// Returns a copy that appends a raw Node option before the selected entry point.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw Node options before the selected entry point.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends an argument passed to the selected script or inline program.
    public func scriptArgument(_ value: String) -> Self { copy(scriptArguments: state.scriptArguments + [value]) }

    /// Returns a copy that appends arguments passed to the selected script or inline program.
    public func scriptArguments(_ values: [String]) -> Self { copy(scriptArguments: state.scriptArguments + values) }

    /// Builds the raw `node` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        for module in state.requires { arguments += ["--require", module] }
        if state.inspects { arguments.append("--inspect") }
        if state.watches { arguments.append("--watch") }
        arguments += state.extraArguments
        switch state.mode {
        case .version: arguments.append("--version")
        case let .eval(code): arguments += ["--eval", code]
        case let .print(code): arguments += ["--print", code]
        case let .check(path): arguments += ["--check", path]
        case let .script(path): arguments.append(path)
        }
        arguments += state.scriptArguments

        let base = Command("node").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        mode: Mode? = nil,
        requires: [String]? = nil,
        inspects: Bool? = nil,
        watches: Bool? = nil,
        extraArguments: [String]? = nil,
        scriptArguments: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                mode: mode ?? state.mode,
                requires: requires ?? state.requires,
                inspects: inspects ?? state.inspects,
                watches: watches ?? state.watches,
                extraArguments: extraArguments ?? state.extraArguments,
                scriptArguments: scriptArguments ?? state.scriptArguments
            )
        )
    }
}

private enum Mode: Sendable {
    case version
    case eval(String)
    case print(String)
    case check(String)
    case script(String)
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let mode: Mode
    let requires: [String]
    let inspects: Bool
    let watches: Bool
    let extraArguments: [String]
    let scriptArguments: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        mode: Mode = .version,
        requires: [String] = [],
        inspects: Bool = false,
        watches: Bool = false,
        extraArguments: [String] = [],
        scriptArguments: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.mode = mode
        self.requires = requires
        self.inspects = inspects
        self.watches = watches
        self.extraArguments = extraArguments
        self.scriptArguments = scriptArguments
    }
}
#endif
