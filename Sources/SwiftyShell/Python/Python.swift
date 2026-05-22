#if Python
import Foundation

/// A fluent wrapper for the Python interpreter CLI (`python3` by default).
///
/// ``Python`` is for script orchestration, not embedded Python interop. It
/// models common interpreter modes such as `-m`, `-c`, and script execution.
///
/// ```swift
/// try await Python()
///     .module("http.server")
///     .argument("8080")
///     .run()
/// ```
public struct Python: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Python command family bound to a shell context.
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

    /// Returns a copy that prints Python version information with `--version`.
    public func version() -> Self { copy(mode: .version, programArguments: []) }

    /// Returns a copy that runs a module with `-m <name>`.
    public func module(_ name: String) -> Self { copy(mode: .module(name), programArguments: []) }

    /// Returns a copy that runs code with `-c <code>`.
    public func commandString(_ code: String) -> Self { copy(mode: .command(code), programArguments: []) }

    /// Returns a copy that runs a Python script path.
    public func script(_ path: String) -> Self { copy(mode: .script(path), programArguments: []) }

    /// Returns a copy that passes `-I` for isolated mode.
    public func isolated(_ enabled: Bool = true) -> Self { copy(isolatedEnabled: enabled) }

    /// Returns a copy that passes `-u` for unbuffered binary stdout and stderr.
    public func unbuffered(_ enabled: Bool = true) -> Self { copy(unbufferedEnabled: enabled) }

    /// Returns a copy that passes `-B` to avoid writing `.pyc` files.
    public func dontWriteBytecode(_ enabled: Bool = true) -> Self { copy(dontWriteBytecodeEnabled: enabled) }

    /// Returns a copy that appends `-O` optimization flags.
    public func optimize(_ level: Int = 1) -> Self { copy(optimizationLevel: level) }

    /// Returns a copy that appends a raw interpreter option before the mode.
    public func option(_ value: String) -> Self { copy(extraOptions: state.extraOptions + [value]) }

    /// Returns a copy that appends raw interpreter options before the mode.
    public func options(_ values: [String]) -> Self { copy(extraOptions: state.extraOptions + values) }

    /// Returns a copy that appends an argument for the selected module, command, or script.
    public func argument(_ value: String) -> Self { copy(programArguments: state.arguments + [value]) }

    /// Returns a copy that appends arguments for the selected module, command, or script.
    public func arguments(_ values: [String]) -> Self { copy(programArguments: state.arguments + values) }

    /// Builds the raw `python3` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        if state.isolatedEnabled { arguments.append("-I") }
        if state.unbufferedEnabled { arguments.append("-u") }
        if state.dontWriteBytecodeEnabled { arguments.append("-B") }
        for _ in 0..<max(0, state.optimizationLevel) { arguments.append("-O") }
        arguments += state.extraOptions
        switch state.mode {
        case .version: arguments.append("--version")
        case let .module(name): arguments += ["-m", name]
        case let .command(code): arguments += ["-c", code]
        case let .script(path): arguments.append(path)
        }
        arguments += state.arguments
        let base = Command("python3").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        mode: Mode? = nil,
        isolatedEnabled: Bool? = nil,
        unbufferedEnabled: Bool? = nil,
        dontWriteBytecodeEnabled: Bool? = nil,
        optimizationLevel: Int? = nil,
        extraOptions: [String]? = nil,
        programArguments: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                mode: mode ?? state.mode,
                isolatedEnabled: isolatedEnabled ?? state.isolatedEnabled,
                unbufferedEnabled: unbufferedEnabled ?? state.unbufferedEnabled,
                dontWriteBytecodeEnabled: dontWriteBytecodeEnabled ?? state.dontWriteBytecodeEnabled,
                optimizationLevel: optimizationLevel ?? state.optimizationLevel,
                extraOptions: extraOptions ?? state.extraOptions,
                arguments: programArguments ?? state.arguments
            )
        )
    }
}

private enum Mode: Sendable {
    case version
    case module(String)
    case command(String)
    case script(String)
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let mode: Mode
    let isolatedEnabled: Bool
    let unbufferedEnabled: Bool
    let dontWriteBytecodeEnabled: Bool
    let optimizationLevel: Int
    let extraOptions: [String]
    let arguments: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        mode: Mode = .version,
        isolatedEnabled: Bool = false,
        unbufferedEnabled: Bool = false,
        dontWriteBytecodeEnabled: Bool = false,
        optimizationLevel: Int = 0,
        extraOptions: [String] = [],
        arguments: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.mode = mode
        self.isolatedEnabled = isolatedEnabled
        self.unbufferedEnabled = unbufferedEnabled
        self.dontWriteBytecodeEnabled = dontWriteBytecodeEnabled
        self.optimizationLevel = optimizationLevel
        self.extraOptions = extraOptions
        self.arguments = arguments
    }
}
#endif
