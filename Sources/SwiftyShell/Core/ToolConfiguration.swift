import Foundation

/// Shared execution overrides used by typed command families.
public struct ToolConfiguration: Sendable {
    /// The shell context associated with the command family.
    public let context: ShellContext
    /// An optional executable override.
    public let executableOverride: String?
    /// Environment variable overrides applied to the final command.
    public let environmentOverrides: [String: String]
    /// An optional working directory override.
    public let workingDirectoryOverride: String?
    /// An optional timeout override in seconds.
    public let timeoutOverride: TimeInterval?
    /// An optional output limit override in bytes.
    public let outputLimitOverride: Int?

    /// Creates a tool configuration with optional execution overrides.
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

    /// Overrides the executable used by the final command.
    public func executable(_ path: String) -> Self {
        copy(executableOverride: path)
    }

    /// Adds or replaces a single environment variable override.
    public func env(_ name: String, _ value: String) -> Self {
        var overrides = environmentOverrides
        overrides[name] = value
        return copy(environmentOverrides: overrides)
    }

    /// Merges environment variable overrides into the configuration.
    public func env(_ values: [String: String]) -> Self {
        copy(environmentOverrides: environmentOverrides.merging(values) { _, new in new })
    }

    /// Overrides the working directory used by the final command.
    public func workingDirectory(_ path: String) -> Self {
        copy(workingDirectoryOverride: path)
    }

    /// Overrides the timeout used by the final command.
    public func timeout(_ seconds: TimeInterval) -> Self {
        copy(timeoutOverride: seconds)
    }

    /// Overrides the output limit used by the final command.
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
