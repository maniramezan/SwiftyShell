import Foundation

/// Shared execution overrides used by typed command families.
///
/// ``ToolConfiguration`` is the carrier for the settings that
/// ``ToolConfigurableCommandFamily`` inherits — executable path, environment
/// variables, working directory, timeout, and output limit. Use it inside a
/// ``RunnableCommandFamily/command()`` implementation by calling ``apply(to:)``:
///
/// ```swift
/// public func command() -> Command {
///     let base = Command("my-tool").args(["--flag"])
///     return state.config.apply(to: base)
/// }
/// ```
public struct ToolConfiguration: Sendable {
    /// The shell context associated with the command family.
    ///
    /// Carried so the family can run built commands without callers needing to thread the
    /// context separately.
    public let context: ShellContext

    /// An optional executable override; `nil` means use ``ShellContext/searchPaths`` resolution.
    public let executableOverride: String?

    /// Environment variable overrides applied to the final command.
    ///
    /// Merged on top of ``ShellContext/environment`` at execution time.
    public let environmentOverrides: [String: String]

    /// An optional working directory override; `nil` means use ``ShellContext/workingDirectory``.
    public let workingDirectoryOverride: String?

    /// An optional timeout override in seconds; `nil` means use ``ShellContext/defaultTimeout``.
    public let timeoutOverride: TimeInterval?

    /// An optional output limit override in bytes; `nil` means use
    /// ``ShellContext/defaultOutputLimit``.
    public let outputLimitOverride: Int?

    /// Creates a tool configuration with optional execution overrides.
    ///
    /// - Parameters:
    ///   - context: The shell context the command family will use to run built commands.
    ///   - executableOverride: An optional explicit executable path. When `nil`, the executor
    ///     resolves the executable name from ``ShellContext/searchPaths``.
    ///   - environmentOverrides: Environment variables merged on top of the context's
    ///     environment for built commands.
    ///   - workingDirectoryOverride: An optional working directory for built commands. When
    ///     `nil`, the context's default applies.
    ///   - timeoutOverride: An optional per-command timeout in seconds. Must be `>= 0`.
    ///   - outputLimitOverride: An optional per-command captured-output limit in bytes. Must be
    ///     `>= 0`.
    public init(
        context: ShellContext = .init(),
        executableOverride: String? = nil,
        environmentOverrides: [String: String] = [:],
        workingDirectoryOverride: String? = nil,
        timeoutOverride: TimeInterval? = nil,
        outputLimitOverride: Int? = nil
    ) {
        self.context = context
        self.executableOverride = executableOverride
        self.environmentOverrides = environmentOverrides
        self.workingDirectoryOverride = workingDirectoryOverride
        self.timeoutOverride = timeoutOverride
        self.outputLimitOverride = outputLimitOverride
    }

    /// Returns a copy that uses the given executable path.
    ///
    /// - Parameter path: An absolute or relative path to the executable.
    /// - Returns: A new configuration with the executable override applied.
    public func executable(_ path: String) -> Self {
        copy(executableOverride: path)
    }

    /// Returns a copy with one environment variable set or replaced.
    ///
    /// - Parameters:
    ///   - name: The environment variable name.
    ///   - value: The value to assign.
    /// - Returns: A new configuration with the environment override applied.
    public func env(_ name: String, _ value: String) -> Self {
        var overrides = environmentOverrides
        overrides[name] = value
        return copy(environmentOverrides: overrides)
    }

    /// Returns a copy with multiple environment variable overrides merged in.
    ///
    /// Keys in `values` win over any overrides previously stored on the configuration.
    ///
    /// - Parameter values: A dictionary of environment variable name/value pairs to merge.
    /// - Returns: A new configuration with the merged environment overrides applied.
    public func env(_ values: [String: String]) -> Self {
        copy(environmentOverrides: environmentOverrides.merging(values) { _, new in new })
    }

    /// Returns a copy that runs the final command in the given working directory.
    ///
    /// - Parameter path: The directory in which to spawn the command.
    /// - Returns: A new configuration with the working-directory override applied.
    public func workingDirectory(_ path: String) -> Self {
        copy(workingDirectoryOverride: path)
    }

    /// Returns a copy with a per-command timeout in seconds.
    ///
    /// The value must be `>= 0`; negative values raise
    /// ``ShellError/invalidConfiguration(description:)`` at execution time.
    ///
    /// - Parameter seconds: The maximum duration to wait for the built command.
    /// - Returns: A new configuration with the timeout override applied.
    public func timeout(_ seconds: TimeInterval) -> Self {
        copy(timeoutOverride: seconds)
    }

    /// Returns a copy with a per-command captured-output limit in bytes.
    ///
    /// The value must be `>= 0`.
    ///
    /// - Parameter bytes: The maximum number of captured-output bytes to retain in memory.
    /// - Returns: A new configuration with the output-limit override applied.
    public func outputLimit(_ bytes: Int) -> Self {
        copy(outputLimitOverride: bytes)
    }

    /// Applies all non-nil overrides in this configuration to a command, returning the updated command.
    ///
    /// Use this method inside a ``RunnableCommandFamily/command()`` implementation to
    /// merge shared tool configuration onto the base ``Command`` before returning it.
    ///
    /// - Parameter command: The base command to apply overrides to.
    /// - Returns: A new ``Command`` with all non-nil overrides applied.
    public func apply(to command: Command) -> Command {
        var cmd = command
        if let executableOverride {
            cmd = cmd.executable(executableOverride)
        }
        if !environmentOverrides.isEmpty {
            cmd = cmd.env(environmentOverrides)
        }
        if let workingDirectoryOverride {
            cmd = cmd.workingDirectory(workingDirectoryOverride)
        }
        if let timeoutOverride {
            cmd = cmd.timeout(timeoutOverride)
        }
        if let outputLimitOverride {
            cmd = cmd.outputLimit(outputLimitOverride)
        }
        return cmd
    }

    private func copy(
        executableOverride: String?? = nil,
        environmentOverrides: [String: String]? = nil,
        workingDirectoryOverride: String?? = nil,
        timeoutOverride: TimeInterval?? = nil,
        outputLimitOverride: Int?? = nil
    ) -> Self {
        Self(
            context: context,
            executableOverride: executableOverride ?? self.executableOverride,
            environmentOverrides: environmentOverrides ?? self.environmentOverrides,
            workingDirectoryOverride: workingDirectoryOverride ?? self.workingDirectoryOverride,
            timeoutOverride: timeoutOverride ?? self.timeoutOverride,
            outputLimitOverride: outputLimitOverride ?? self.outputLimitOverride
        )
    }
}
