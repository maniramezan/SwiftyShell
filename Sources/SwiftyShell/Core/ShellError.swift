import Foundation

/// Identifies a command output stream.
///
/// Carried by ``ShellError/decodingError(command:stream:)`` to indicate which stream failed to
/// decode as UTF-8.
public enum StreamKind: Sendable {
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
public enum ShellError: Error, LocalizedError, Sendable {
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
    ///   - command: The shell-quoted display string of the command that failed.
    ///   - output: The captured ``ShellOutput`` (including ``ShellOutput/exitCode``).
    case exitFailure(command: String, output: ShellOutput)

    /// The command exceeded the configured timeout and was terminated.
    ///
    /// - Parameters:
    ///   - command: The shell-quoted display string of the command that timed out.
    ///   - duration: The timeout in seconds that was exceeded.
    ///   - partialOutput: Whatever output was captured before the process was terminated.
    case timeout(command: String, duration: TimeInterval, partialOutput: ShellOutput)

    /// A captured output stream contained bytes that could not be decoded as UTF-8.
    ///
    /// - Parameters:
    ///   - command: The shell-quoted display string of the command whose output failed to decode.
    ///   - stream: Which stream failed to decode (``StreamKind/stdout`` or
    ///     ``StreamKind/stderr``).
    case decodingError(command: String, stream: StreamKind)

    /// Captured output exceeded the configured limit and the process was terminated.
    ///
    /// - Parameters:
    ///   - command: The shell-quoted display string of the command.
    ///   - limit: The output limit in bytes that was exceeded.
    ///   - partialOutput: Whatever output was captured up to the limit.
    case outputLimitExceeded(command: String, limit: Int, partialOutput: ShellOutput)

    /// The command was cancelled (typically via task cancellation) before it completed.
    ///
    /// - Parameters:
    ///   - command: The shell-quoted display string of the cancelled command.
    ///   - partialOutput: Whatever output was captured before cancellation.
    case cancelled(command: String, partialOutput: ShellOutput)

    /// The process could not be started (for example missing permissions or invalid arguments).
    ///
    /// - Parameters:
    ///   - command: The shell-quoted display string of the command.
    ///   - reason: A human-readable description of why the spawn failed.
    case spawnError(command: String, reason: String)

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
            return "'\(command)' timed out after \(duration) seconds"
        case let .decodingError(command, stream):
            return "Failed to decode \(stream) output for '\(command)' as UTF-8"
        case let .outputLimitExceeded(command, limit, _):
            return "'\(command)' exceeded the output limit of \(limit) bytes"
        case let .cancelled(command, _):
            return "'\(command)' was cancelled"
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
                "ShellError.timeout(command: \(command.debugDescription), duration: \(duration)s, partialOutput: \(partialOutput.debugDescription))"
        case let .outputLimitExceeded(command, limit, partialOutput):
            return
                "ShellError.outputLimitExceeded(command: \(command.debugDescription), limit: \(limit), partialOutput: \(partialOutput.debugDescription))"
        case let .cancelled(command, partialOutput):
            return
                "ShellError.cancelled(command: \(command.debugDescription), partialOutput: \(partialOutput.debugDescription))"
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
