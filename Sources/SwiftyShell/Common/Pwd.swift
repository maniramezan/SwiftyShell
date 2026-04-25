#if Pwd
import Foundation

/// A fluent wrapper for the `pwd` command.
///
/// Use ``Pwd`` to read the command's current working directory from ``ShellOutput/stdout``.
/// ``physical(_:)`` resolves symlinks; ``logical(_:)`` preserves the logical path when possible.
///
/// ```swift
/// let output = try await Pwd(context: context)
///     .physical()    // Resolve symlinks before printing the path.
///     .run()
///
/// let path = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
/// ```
public struct Pwd: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `pwd` command family bound to a shell context.
    ///
    /// All builder state starts empty: neither ``physical(_:)`` nor ``logical(_:)`` is enabled,
    /// which lets `pwd` use its built-in default (logical on most shells).
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Pwd`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `pwd` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Stdout is the path itself, so this is the
    /// stream most callers will inspect (typically with `.trimmingCharacters(in:)` to strip the
    /// trailing newline).
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Pwd`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `pwd` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `pwd` rarely emits stderr.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Pwd`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that prints the physical working directory with symlinks resolved.
    ///
    /// Maps to the `-P` flag. Mutually exclusive with ``logical(_:)`` — enabling one disables
    /// the other so the final command never carries both flags.
    ///
    /// - Parameter enabled: `true` to add `-P`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Pwd`` value with the flag applied.
    public func physical(_ enabled: Bool = true) -> Self {
        copy(usesPhysicalPath: enabled, usesLogicalPath: enabled ? false : state.usesLogicalPath)
    }

    /// Returns a copy that prints the logical working directory, preserving symlinks where
    /// possible.
    ///
    /// Maps to the `-L` flag. Mutually exclusive with ``physical(_:)`` — enabling one disables
    /// the other so the final command never carries both flags.
    ///
    /// - Parameter enabled: `true` to add `-L`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Pwd`` value with the flag applied.
    public func logical(_ enabled: Bool = true) -> Self {
        copy(usesPhysicalPath: enabled ? false : state.usesPhysicalPath, usesLogicalPath: enabled)
    }

    /// Builds the raw `pwd` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: `-P` (when set), `-L` (when set). At most one of these
    /// will be present because the helpers above are mutually exclusive. The shared
    /// ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.usesPhysicalPath {
            arguments.append("-P")
        }
        if state.usesLogicalPath {
            arguments.append("-L")
        }

        let base = Command("pwd")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        usesPhysicalPath: Bool? = nil,
        usesLogicalPath: Bool? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                usesPhysicalPath: usesPhysicalPath ?? state.usesPhysicalPath,
                usesLogicalPath: usesLogicalPath ?? state.usesLogicalPath
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let usesPhysicalPath: Bool
    let usesLogicalPath: Bool

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        usesPhysicalPath: Bool = false,
        usesLogicalPath: Bool = false
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.usesPhysicalPath = usesPhysicalPath
        self.usesLogicalPath = usesLogicalPath
    }
}
#endif
