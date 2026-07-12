#if Mkdir
import Foundation

/// A fluent wrapper for the `mkdir` command.
///
/// Use ``Mkdir`` to create one or more directories. This example maps to
/// `mkdir -p -m 755 /tmp/output/logs`: parent directories are created as needed, and the typed
/// ``FileMode`` documents the intended POSIX permissions at the call site.
///
/// ```swift
/// try await Mkdir(context: context)
///     .parents()    // Create missing parent directories.
///     .mode(
///         FileMode(
///             owner: [.read, .write, .execute],
///             group: [.read, .execute],
///             other: [.read, .execute]
///         )
///     )
///     .directory("/tmp/output/logs")
///     .run()
/// ```
public struct Mkdir: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `mkdir` command family bound to a shell context.
    ///
    /// All builder state starts empty: no directories, no flags. Configure with the fluent
    /// helpers before calling ``run()`` or ``command()``.
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
    /// - Returns: A new ``Mkdir`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `mkdir` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `mkdir` typically produces no stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Mkdir`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `mkdir` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `mkdir` writes diagnostics here when a path
    /// already exists or when permission is denied.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Mkdir`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that creates intermediate parent directories as needed.
    ///
    /// Maps to the `-p` flag. With this enabled, missing parent directories are created
    /// automatically and `mkdir` does not fail if the target directory already exists — the
    /// idempotent "make sure this exists" semantics most callers want.
    ///
    /// ```swift
    /// try await Mkdir(context: context)
    ///     .parents()
    ///     .directory("/tmp/output/logs")
    ///     .run()
    /// ```
    ///
    /// - Parameter enabled: `true` to add `-p`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Mkdir`` value with the flag applied.
    public func parents(_ enabled: Bool = true) -> Self {
        copy(createsIntermediateDirectories: enabled)
    }

    /// Returns a copy with the mode passed to `mkdir -m` set from a typed ``FileMode``.
    ///
    /// Replaces any previously configured mode. This overload is preferred at call sites
    /// because the typed permission sets read like prose and avoid memorizing octal digits.
    ///
    /// - Parameter value: The typed file-mode value rendered as the `-m` argument.
    /// - Returns: A new ``Mkdir`` value with the mode applied.
    public func mode(_ value: FileMode) -> Self {
        copy(modeValue: value.rawValue)
    }

    /// Returns a copy with the mode passed to `mkdir -m` set from a raw mode string.
    ///
    /// Use this overload to forward an octal string (such as `"755"`) or symbolic mode (such as
    /// `"u+rwx,go+rx"`) verbatim. Prefer ``mode(_:)-(FileMode)`` (the ``FileMode`` overload) when
    /// composing modes in code.
    ///
    /// - Parameter value: The literal `-m` argument value.
    /// - Returns: A new ``Mkdir`` value with the mode applied.
    public func mode(_ value: String) -> Self {
        copy(modeValue: value)
    }

    /// Returns a copy with one additional directory path appended for creation.
    ///
    /// - Parameter path: The directory path to create.
    /// - Returns: A new ``Mkdir`` value with the path appended.
    public func directory(_ path: String) -> Self {
        copy(directories: state.directories + [path])
    }

    /// Returns a copy with multiple directory paths appended for creation.
    ///
    /// - Parameter paths: The directory paths to append, in order.
    /// - Returns: A new ``Mkdir`` value with the paths appended.
    public func directories(_ paths: [String]) -> Self {
        copy(directories: state.directories + paths)
    }

    /// Builds the raw `mkdir` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: `-p`, then `-m <mode>`, then directory paths. The shared
    /// ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.createsIntermediateDirectories {
            arguments.append("-p")
        }
        if let modeValue = state.modeValue {
            arguments.append(contentsOf: ["-m", modeValue])
        }

        if !state.directories.isEmpty { arguments.append("--") }
        arguments.append(contentsOf: state.directories)

        let base = Command("mkdir")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        createsIntermediateDirectories: Bool? = nil,
        modeValue: String?? = nil,
        directories: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                createsIntermediateDirectories: createsIntermediateDirectories ?? state.createsIntermediateDirectories,
                modeValue: modeValue ?? state.modeValue,
                directories: directories ?? state.directories
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let createsIntermediateDirectories: Bool
    let modeValue: String?
    let directories: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        createsIntermediateDirectories: Bool = false,
        modeValue: String? = nil,
        directories: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.createsIntermediateDirectories = createsIntermediateDirectories
        self.modeValue = modeValue
        self.directories = directories
    }
}
#endif
