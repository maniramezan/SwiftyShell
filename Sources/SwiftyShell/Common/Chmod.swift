#if Chmod
import Foundation

/// A fluent wrapper for the `chmod` command.
///
/// ```swift
/// // Set directory permissions recursively
/// try await Chmod(context: context)
///     .recursive()
///     .mode(
///         FileMode(
///             owner: [.read, .write, .execute],
///             group: [.read, .execute],
///             other: [.read, .execute]
///         )
///     )
///     .path("/tmp/output")
///     .run()
/// ```
public struct Chmod: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `chmod` command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Redirects stdout for the built `chmod` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `chmod` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Applies permission changes recursively.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Sets the mode passed to `chmod` using a typed octal value.
    public func mode(_ value: FileMode) -> Self {
        copy(modeValue: value.rawValue)
    }

    /// Sets the mode passed to `chmod`.
    public func mode(_ value: String) -> Self {
        copy(modeValue: value)
    }

    /// Appends a path whose permissions should be updated.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Appends multiple paths whose permissions should be updated.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `chmod` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.isRecursive {
            arguments.append("-R")
        }
        if let modeValue = state.modeValue {
            arguments.append(modeValue)
        }

        arguments.append(contentsOf: state.paths)

        let base = Command("chmod")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isRecursive: Bool? = nil,
        modeValue: String?? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                isRecursive: isRecursive ?? state.isRecursive,
                modeValue: modeValue ?? state.modeValue,
                paths: paths ?? state.paths
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isRecursive: Bool
    let modeValue: String?
    let paths: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isRecursive: Bool = false,
        modeValue: String? = nil,
        paths: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isRecursive = isRecursive
        self.modeValue = modeValue
        self.paths = paths
    }
}
#endif
