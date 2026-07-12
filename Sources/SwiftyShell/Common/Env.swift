#if Env
import Foundation

/// A typed wrapper for printing or modifying an environment with `env`.
///
/// Invoked command arguments remain separate argv values and are never interpreted by a shell.
///
/// ```swift
/// try await Env()
///     .clean()
///     .set("LANG", "C")
///     .command("printenv", arguments: ["LANG"])
///     .run()
/// ```
public struct Env: RunnableCommandFamily {
    private let state: State

    /// The shell context used to execute the command.
    public var context: ShellContext { state.config.context }

    /// Creates an `env` command that initially prints the inherited environment.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy with the command's stdout destination changed.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy with the command's stderr destination changed.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that starts with an empty environment.
    ///
    /// - Parameter enabled: Whether to pass the portable `-i` option.
    public func clean(_ enabled: Bool = true) -> Self {
        copy(ignoresInheritedEnvironment: enabled)
    }

    /// Returns a copy that sets or replaces a variable in the resulting environment.
    ///
    /// - Parameters:
    ///   - name: A portable environment variable name.
    ///   - value: The value assigned to the variable.
    public func set(_ name: String, _ value: String) -> Self {
        var assignments = state.assignments
        assignments[name] = value
        return copy(assignments: assignments)
    }

    /// Returns a copy that sets or replaces multiple variables.
    public func set(_ values: [String: String]) -> Self {
        copy(assignments: state.assignments.merging(values) { _, new in new })
    }

    /// Returns a copy that removes a variable from the resulting environment.
    ///
    /// `-u` is supported by the macOS/BSD and GNU implementations of `env`.
    public func unset(_ name: String) -> Self {
        copy(unsetNames: state.unsetNames + [name])
    }

    /// Returns a copy that invokes a utility with separate, shell-safe argv values.
    ///
    /// - Parameters:
    ///   - executable: The utility name or path passed to `env`.
    ///   - arguments: Arguments passed directly to that utility without shell parsing.
    public func command(_ executable: String, arguments: [String] = []) -> Self {
        copy(invocation: Invocation(executable: executable, arguments: arguments))
    }

    /// Builds the configured `env` command.
    public func command() -> Command {
        var arguments: [String] = []
        if state.ignoresInheritedEnvironment { arguments.append("-i") }
        for name in state.unsetNames { arguments.append(contentsOf: ["-u", name]) }
        for (name, value) in state.assignments.sorted(by: { $0.key < $1.key }) {
            arguments.append("\(name)=\(value)")
        }
        if let invocation = state.invocation {
            arguments.append(invocation.executable)
            arguments.append(contentsOf: invocation.arguments)
        }

        return state.config.apply(
            to: Command("env")
                .args(arguments)
                .stdout(state.stdoutDestination)
                .stderr(state.stderrDestination)
        )
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        ignoresInheritedEnvironment: Bool? = nil,
        assignments: [String: String]? = nil,
        unsetNames: [String]? = nil,
        invocation: Invocation?? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                ignoresInheritedEnvironment: ignoresInheritedEnvironment ?? state.ignoresInheritedEnvironment,
                assignments: assignments ?? state.assignments,
                unsetNames: unsetNames ?? state.unsetNames,
                invocation: invocation ?? state.invocation
            )
        )
    }
}

private struct Invocation: Sendable {
    let executable: String
    let arguments: [String]
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let ignoresInheritedEnvironment: Bool
    let assignments: [String: String]
    let unsetNames: [String]
    let invocation: Invocation?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        ignoresInheritedEnvironment: Bool = false,
        assignments: [String: String] = [:],
        unsetNames: [String] = [],
        invocation: Invocation? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.ignoresInheritedEnvironment = ignoresInheritedEnvironment
        self.assignments = assignments
        self.unsetNames = unsetNames
        self.invocation = invocation
    }
}
#endif
