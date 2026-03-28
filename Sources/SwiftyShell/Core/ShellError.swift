import Foundation

/// Identifies a command output stream.
public enum StreamKind: Sendable {
    /// Standard output.
    case stdout
    /// Standard error.
    case stderr
}

/// Errors thrown while building workflows or running shell commands.
public enum ShellError: Error, LocalizedError, Sendable {
    /// The requested executable could not be resolved.
    case commandNotFound(String)
    /// The command exited with a non-zero status code.
    case exitFailure(command: String, output: ShellOutput)
    /// The command exceeded the configured timeout.
    case timeout(command: String, duration: TimeInterval, partialOutput: ShellOutput)
    /// A captured output stream could not be decoded as UTF-8.
    case decodingError(command: String, stream: StreamKind)
    /// Captured output exceeded the configured limit.
    case outputLimitExceeded(command: String, limit: Int, partialOutput: ShellOutput)
    /// The command was cancelled before completion.
    case cancelled(command: String, partialOutput: ShellOutput)
    /// The process could not be started.
    case spawnError(command: String, reason: String)
    /// A workflow requirement failed.
    case workflowConditionFailed(description: String)

    /// A localized description of the shell error.
    public var errorDescription: String? {
        switch self {
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
    public var debugDescription: String {
        switch self {
        case let .exitFailure(command, output):
            return "ShellError.exitFailure(command: \(command.debugDescription), exitCode: \(output.exitCode), stderr: \(output.stderr.debugDescription))"
        case let .timeout(command, duration, partialOutput):
            return "ShellError.timeout(command: \(command.debugDescription), duration: \(duration)s, partialOutput: \(partialOutput.debugDescription))"
        case let .outputLimitExceeded(command, limit, partialOutput):
            return "ShellError.outputLimitExceeded(command: \(command.debugDescription), limit: \(limit), partialOutput: \(partialOutput.debugDescription))"
        case let .cancelled(command, partialOutput):
            return "ShellError.cancelled(command: \(command.debugDescription), partialOutput: \(partialOutput.debugDescription))"
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
