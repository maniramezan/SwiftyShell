import Foundation

/// A value describing a single shell command and its execution overrides.
public struct Command: Sendable {
    /// The executable name originally requested for the command.
    public let executableName: String
    /// The argv arguments passed to the executable.
    public let arguments: [String]
    /// An optional absolute or relative executable override.
    public let executableOverride: String?
    /// Environment variable overrides applied when running the command.
    public let environmentOverrides: [String: String]
    /// An optional working directory override.
    public let workingDirectoryOverride: String?
    /// An optional timeout override in seconds.
    public let timeoutOverride: TimeInterval?
    /// An optional output capture limit in bytes.
    public let outputLimitOverride: Int?
    /// The stdout handling strategy.
    public let stdoutDestination: OutputDestination
    /// The stderr handling strategy.
    public let stderrDestination: OutputDestination

    /// Creates a command from an executable name and optional arguments.
    public init(_ executable: String, _ arguments: String...) {
        self.executableName = executable
        self.arguments = arguments
        self.executableOverride = nil
        self.environmentOverrides = [:]
        self.workingDirectoryOverride = nil
        self.timeoutOverride = nil
        self.outputLimitOverride = nil
        self.stdoutDestination = .capture
        self.stderrDestination = .capture
    }

    private init(
        executableName: String,
        arguments: [String],
        executableOverride: String?,
        environmentOverrides: [String: String],
        workingDirectoryOverride: String?,
        timeoutOverride: TimeInterval?,
        outputLimitOverride: Int?,
        stdoutDestination: OutputDestination,
        stderrDestination: OutputDestination
    ) {
        self.executableName = executableName
        self.arguments = arguments
        self.executableOverride = executableOverride
        self.environmentOverrides = environmentOverrides
        self.workingDirectoryOverride = workingDirectoryOverride
        self.timeoutOverride = timeoutOverride
        self.outputLimitOverride = outputLimitOverride
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
    }

    /// Overrides the executable path used when running the command.
    public func executable(_ path: String) -> Self {
        copy(executableOverride: path)
    }

    /// Appends a single argv argument.
    public func arg(_ value: String) -> Self {
        copy(arguments: arguments + [value])
    }

    /// Appends multiple argv arguments.
    public func args(_ values: [String]) -> Self {
        copy(arguments: arguments + values)
    }

    /// Adds or replaces a single environment variable override.
    public func env(_ name: String, _ value: String) -> Self {
        var overrides = environmentOverrides
        overrides[name] = value
        return copy(environmentOverrides: overrides)
    }

    /// Merges environment variable overrides into the command.
    public func env(_ values: [String: String]) -> Self {
        copy(environmentOverrides: environmentOverrides.merging(values) { _, new in new })
    }

    /// Overrides the working directory used when running the command.
    public func workingDirectory(_ path: String) -> Self {
        copy(workingDirectoryOverride: path)
    }

    /// Overrides the timeout used when running the command.
    public func timeout(_ seconds: TimeInterval) -> Self {
        copy(timeoutOverride: seconds)
    }

    /// Overrides the output capture limit used when running the command.
    public func outputLimit(_ bytes: Int) -> Self {
        copy(outputLimitOverride: bytes)
    }

    /// Redirects stdout for the command.
    public func stdout(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the command.
    public func stderr(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Creates a pipeline by connecting this command to another command.
    public func pipe(to next: Command) -> Pipeline {
        Pipeline(stages: [self, next])
    }

    /// Runs the command using the provided shell context.
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput {
        try await context.executor.execute(self, in: context)
    }

    internal func displayString(using resolvedExecutable: String? = nil) -> String {
        ([resolvedExecutable ?? executableOverride ?? executableName] + arguments)
            .map(Self.quoteIfNeeded)
            .joined(separator: " ")
    }

    private static func quoteIfNeeded(_ component: String) -> String {
        if component.contains(where: \.isWhitespace) {
            return "\"\(component.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return component
    }

    private func copy(
        executableName: String? = nil,
        arguments: [String]? = nil,
        executableOverride: String?? = nil,
        environmentOverrides: [String: String]? = nil,
        workingDirectoryOverride: String?? = nil,
        timeoutOverride: TimeInterval?? = nil,
        outputLimitOverride: Int?? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil
    ) -> Self {
        Self(
            executableName: executableName ?? self.executableName,
            arguments: arguments ?? self.arguments,
            executableOverride: executableOverride ?? self.executableOverride,
            environmentOverrides: environmentOverrides ?? self.environmentOverrides,
            workingDirectoryOverride: workingDirectoryOverride ?? self.workingDirectoryOverride,
            timeoutOverride: timeoutOverride ?? self.timeoutOverride,
            outputLimitOverride: outputLimitOverride ?? self.outputLimitOverride,
            stdoutDestination: stdoutDestination ?? self.stdoutDestination,
            stderrDestination: stderrDestination ?? self.stderrDestination
        )
    }
}
