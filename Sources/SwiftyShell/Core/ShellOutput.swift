import Foundation

/// The captured result of running a command or pipeline.
///
/// After `run()` returns, inspect `stdout`, `stderr`, and `exitCode` to understand
/// what the process produced:
///
/// ```swift
/// let output = try await Command("git", "rev-parse", "HEAD").run(in: context)
/// let sha = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
///
/// guard output.isSuccess else {
///     print("git failed:", output.stderr)
/// }
/// ```
///
/// When running typed command families, errors are surfaced as ``ShellError``
/// rather than requiring manual exit-code inspection.
public struct ShellOutput: Sendable, Equatable {
    /// Captured stdout text.
    public var stdout: String
    /// Captured stderr text.
    public var stderr: String
    /// Process exit status.
    public var exitCode: Int32

    /// Indicates whether the command exited successfully.
    public var isSuccess: Bool {
        exitCode == 0
    }

    /// Creates a shell output value from captured streams and an exit code.
    public init(stdout: String = "", stderr: String = "", exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

extension ShellOutput: CustomStringConvertible {
    /// Returns stdout, or stderr if stdout is empty.
    public var description: String {
        stdout.isEmpty ? stderr : stdout
    }
}

extension ShellOutput: CustomDebugStringConvertible {
    /// Returns a detailed debug representation including exit code, stdout, and stderr.
    public var debugDescription: String {
        "ShellOutput(exitCode: \(exitCode), stdout: \(stdout.debugDescription), stderr: \(stderr.debugDescription))"
    }
}
