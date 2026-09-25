import Foundation

/// Identifies a command output stream.
///
/// Carried by ``ShellError/decodingError(command:stream:)-enum.case`` to indicate which stream failed to
/// decode as UTF-8.
public enum StreamKind: Sendable, Equatable {
    /// Standard output.
    case stdout
    /// Standard error.
    case stderr
}

/// Errors thrown while building workflows or running shell commands.
///
/// Every public SwiftyShell entry point that can fail surfaces failures through ``ShellError``.
/// Catch the specific case you care about and let the rest re-throw, or pattern-match on the
/// payload to surface diagnostics:
///
/// ```swift
/// do {
///     let output = try await Command("git", arguments: "push").run(in: context)
/// } catch ShellError.commandNotFound(let cmd) {
///     print("\(cmd) is not installed or not on the search path")
/// } catch ShellError.exitFailure(_, let output) {
///     print("Push failed:", output.stderr)
/// } catch ShellError.timeout(let cmd, let duration, _) {
///     print("\(cmd) timed out after \(duration)s")
/// }
/// ```
public enum ShellError: Error, LocalizedError, Sendable, Equatable {
    /// A timeout, output-limit, or other configuration value was invalid (for example negative).
    ///
    /// - Parameter description: A human-readable explanation of the misconfiguration.
    case invalidConfiguration(description: String)

    /// The requested executable could not be resolved against ``ShellContext/searchPaths``.
    ///
    /// The associated value is the executable name that failed to resolve.
    case commandNotFound(String)

    /// The command exited with a non-zero status code.
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the command that failed.
    ///   - output: The captured ``ShellOutput`` (including ``ShellOutput/exitCode``).
    case exitFailure(command: CommandSnapshot, output: ShellOutput)

    /// The command exceeded the configured timeout and was terminated.
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the command that timed out.
    ///   - duration: The timeout that was exceeded.
    ///   - partialOutput: Whatever output was captured before the process was terminated.
    case timeout(command: CommandSnapshot, duration: Duration, partialOutput: ShellOutput)

    /// A captured output stream contained bytes that could not be decoded as UTF-8.
    ///
    /// Typed workflows that parse stdout (for example `Git` status or `Which` lookup) throw this
    /// instead of parsing U+FFFD replacement characters. Plain `run()` calls do not throw it; they
    /// return the raw bytes in ``ShellOutput/stdoutData``.
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the command whose output failed to decode.
    ///   - stream: Which stream failed to decode (``StreamKind/stdout`` or
    ///     ``StreamKind/stderr``).
    case decodingError(command: CommandSnapshot, stream: StreamKind)

    /// A command succeeded, but its structured output did not match the expected format.
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the command that produced malformed output.
    ///   - reason: A human-readable description of the malformed record.
    case parsingError(command: CommandSnapshot, reason: String)

    /// Captured output exceeded the configured limit and the process was terminated.
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the command.
    ///   - limit: The output limit in bytes that was exceeded.
    ///   - partialOutput: Whatever output was captured up to the limit.
    case outputLimitExceeded(command: CommandSnapshot, limit: Int, partialOutput: ShellOutput)

    /// The command was canceled (typically via task cancellation) before it completed.
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the canceled command.
    ///   - partialOutput: Whatever output was captured before cancellation.
    case canceled(command: CommandSnapshot, partialOutput: ShellOutput)

    /// The process could not be started (for example missing permissions or invalid arguments).
    ///
    /// - Parameters:
    ///   - command: The executable and argv snapshot of the command.
    ///   - reason: A human-readable description of why the spawn failed.
    case spawnError(command: CommandSnapshot, reason: String)

    /// A workflow precondition supplied to ``Workflow/require(_:else:)`` (or its key-path
    /// overload) failed.
    ///
    /// - Parameter description: A human-readable explanation of the failed condition.
    case workflowConditionFailed(description: String)

    /// A localized description of the shell error.
    ///
    /// Suitable for display to end users. For richer machine-readable detail, switch on the
    /// case directly to access associated values such as ``ShellOutput`` or `partialOutput`.
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(description):
            return description
        case let .commandNotFound(command):
            return "Command not found: \(command)"
        case let .exitFailure(command, output):
            return "'\(command)' exited with status \(output.exitCode)"
        case let .timeout(command, duration, _):
            return "'\(command)' timed out after \(duration)"
        case let .decodingError(command, stream):
            return "Failed to decode \(stream) output for '\(command)' as UTF-8"
        case let .parsingError(command, reason):
            return "Failed to parse output for '\(command)': \(reason)"
        case let .outputLimitExceeded(command, limit, _):
            return "'\(command)' exceeded the output limit of \(limit) bytes"
        case let .canceled(command, _):
            return "'\(command)' was canceled"
        case let .spawnError(command, reason):
            return "Failed to spawn '\(command)': \(reason)"
        case let .workflowConditionFailed(description):
            return description
        }
    }
}

extension ShellError: CustomStringConvertible {
    /// Returns the localized error description.
    public var description: String {
        errorDescription ?? localizedDescription
    }
}

extension ShellError: CustomDebugStringConvertible {
    /// Returns a detailed debug representation including captured output where applicable.
    public var debugDescription: String {
        switch self {
        case let .invalidConfiguration(description):
            return "ShellError.invalidConfiguration(description: \(description.debugDescription))"
        case let .exitFailure(command, output):
            return
                "ShellError.exitFailure(command: \(command.debugDescription), exitCode: \(output.exitCode), stderr: \(output.stderr.debugDescription))"
        case let .timeout(command, duration, partialOutput):
            return
                "ShellError.timeout(command: \(command.debugDescription), duration: \(duration), partialOutput: \(partialOutput.debugDescription))"
        case let .outputLimitExceeded(command, limit, partialOutput):
            return
                "ShellError.outputLimitExceeded(command: \(command.debugDescription), limit: \(limit), partialOutput: \(partialOutput.debugDescription))"
        case let .canceled(command, partialOutput):
            return
                "ShellError.canceled(command: \(command.debugDescription), partialOutput: \(partialOutput.debugDescription))"
        default:
            return "ShellError(\(errorDescription ?? localizedDescription))"
        }
    }
}

extension StreamKind: CustomStringConvertible {
    /// A lowercase string representation of the stream kind.
    public var description: String {
        switch self {
        case .stdout: "stdout"
        case .stderr: "stderr"
        }
    }
}

public extension ShellError {
    /// Creates a `exitFailure` error from legacy display text without parsing argv.
    static func exitFailure(command: String, output: ShellOutput) -> Self {
        .exitFailure(command: CommandSnapshot(displayString: command), output: output)
    }

    /// Creates a `timeout` error from legacy display text without parsing argv.
    static func timeout(command: String, duration: Duration, partialOutput: ShellOutput) -> Self {
        .timeout(command: CommandSnapshot(displayString: command), duration: duration, partialOutput: partialOutput)
    }

    /// Creates a `decodingError` error from legacy display text without parsing argv.
    static func decodingError(command: String, stream: StreamKind) -> Self {
        .decodingError(command: CommandSnapshot(displayString: command), stream: stream)
    }

    /// Creates a `parsingError` error from legacy display text without parsing argv.
    static func parsingError(command: String, reason: String) -> Self {
        .parsingError(command: CommandSnapshot(displayString: command), reason: reason)
    }

    /// Creates a `outputLimitExceeded` error from legacy display text without parsing argv.
    static func outputLimitExceeded(command: String, limit: Int, partialOutput: ShellOutput) -> Self {
        .outputLimitExceeded(
            command: CommandSnapshot(displayString: command),
            limit: limit,
            partialOutput: partialOutput
        )
    }

    /// Creates a `canceled` error from legacy display text without parsing argv.
    static func canceled(command: String, partialOutput: ShellOutput) -> Self {
        .canceled(command: CommandSnapshot(displayString: command), partialOutput: partialOutput)
    }

    /// Creates a `spawnError` error from legacy display text without parsing argv.
    static func spawnError(command: String, reason: String) -> Self {
        .spawnError(command: CommandSnapshot(displayString: command), reason: reason)
    }

}
