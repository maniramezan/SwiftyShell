#if Chmod
import Foundation

/// A fluent wrapper for the `chmod` command.
///
/// Use ``Chmod`` to change permissions with either a typed ``FileMode`` or a shell-ready mode
/// string. This example recursively grants the owner full access and grants read/execute access to
/// the group and others.
///
/// ```swift
/// try await Chmod(context: context)
///     .recursive()    // Apply the permission change to descendants too.
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
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `chmod` command family bound to a shell context.
    ///
    /// All builder state starts empty: no mode, no paths, no flags. Configure with the fluent
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
    /// - Returns: A new ``Chmod`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `chmod` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `chmod` typically produces no stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Chmod`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `chmod` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `chmod` writes diagnostics here when paths
    /// cannot be modified.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Chmod`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that applies permission changes recursively to descendants.
    ///
    /// Maps to the `-R` flag. Required to change the permissions of a directory's contents in
    /// addition to the directory itself.
    ///
    /// - Parameter enabled: `true` to add `-R`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Chmod`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Returns a copy with the mode passed to `chmod` set from a typed ``FileMode``.
    ///
    /// Replaces any previously configured mode. This overload is preferred at call sites
    /// because the typed permission sets read like prose and avoid memorizing octal digits.
    ///
    /// - Parameter value: The typed file-mode value rendered as the mode argument.
    /// - Returns: A new ``Chmod`` value with the mode applied.
    public func mode(_ value: FileMode) -> Self {
        copy(modeValue: value.rawValue)
    }

    /// Returns a copy with the mode passed to `chmod` set from a raw mode string.
    ///
    /// Use this overload to forward an octal string (such as `"755"`) or a symbolic mode (such
    /// as `"u+rwx,go+rx"`) verbatim. Prefer ``mode(_:)-(FileMode)`` (the ``FileMode`` overload) when
    /// composing modes in code.
    ///
    /// - Parameter value: The literal mode argument value.
    /// - Returns: A new ``Chmod`` value with the mode applied.
    public func mode(_ value: String) -> Self {
        copy(modeValue: value)
    }

    /// Returns a copy with one additional path appended whose permissions should be updated.
    ///
    /// - Parameter value: The file or directory path to update.
    /// - Returns: A new ``Chmod`` value with the path appended.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Returns a copy with multiple paths appended whose permissions should be updated.
    ///
    /// - Parameter values: The paths to append, in order.
    /// - Returns: A new ``Chmod`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `chmod` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: `-R` (when set), then the mode, then paths. The shared
    /// ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
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
