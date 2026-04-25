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
    /// The captured stdout text, decoded as UTF-8.
    ///
    /// Empty when the command produced no stdout, when stdout was routed to
    /// ``OutputDestination/discard``, or when stdout was routed to
    /// ``OutputDestination/file(path:append:)``.
    public var stdout: String

    /// The captured stderr text, decoded as UTF-8.
    ///
    /// Empty when the command produced no stderr or when stderr was routed elsewhere via
    /// ``OutputDestination``.
    public var stderr: String

    /// The process exit status code.
    ///
    /// `0` indicates success; any non-zero value indicates failure. When using
    /// ``Command/run(in:)`` or any typed command family's `run()`, a non-zero exit raises
    /// ``ShellError/exitFailure(command:output:)`` rather than returning a `ShellOutput` for
    /// the caller to inspect.
    public var exitCode: Int32

    /// Indicates whether the command exited successfully (``exitCode`` equals zero).
    public var isSuccess: Bool {
        exitCode == 0
    }

    /// Creates a shell output value from captured streams and an exit code.
    ///
    /// Useful for constructing ``MockExecutor`` responses in tests or for synthesizing values in
    /// custom executors.
    ///
    /// - Parameters:
    ///   - stdout: The stdout text to expose. Defaults to `""`.
    ///   - stderr: The stderr text to expose. Defaults to `""`.
    ///   - exitCode: The process exit status code. Use `0` to represent success.
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
