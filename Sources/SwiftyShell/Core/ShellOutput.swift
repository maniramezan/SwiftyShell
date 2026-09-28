import Foundation

/// The captured result of running a command or pipeline.
///
/// After `run()` returns, inspect `stdout`, `stderr`, and `exitCode` to understand
/// what the process produced. The captured bytes are kept as-is in ``stdoutData`` and
/// ``stderrData``; ``stdout`` and ``stderr`` decode them as UTF-8:
///
/// ```swift
/// let output = try await Command("git", arguments: "rev-parse", "HEAD").run(in: context)
/// let sha = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
///
/// guard output.isSuccess else {
///     print("git failed:", output.stderr)
/// }
/// ```
///
/// The built-in executors throw ``ShellError/exitFailure(command:output:)-enum.case`` for non-zero exits
/// from both raw commands and typed command families, so successful `run()` calls normally return
/// an output whose ``isSuccess`` is `true`. Inspect the output attached to `exitFailure` for a
/// failed process.
public struct ShellOutput: Sendable, Equatable {
    /// The captured stdout bytes, exactly as the process wrote them.
    ///
    /// Use this for binary output such as archives or images, or when you need to validate the
    /// encoding yourself:
    ///
    /// ```swift
    /// let output = try await Command("tar", arguments: "-cz", "Sources").run(in: context)
    /// try output.stdoutData.write(to: archiveURL)
    /// ```
    ///
    /// Empty under the same conditions as ``stdout``.
    public var stdoutData: Data

    /// The captured stderr bytes, exactly as the process wrote them.
    ///
    /// Empty under the same conditions as ``stderr``.
    public var stderrData: Data

    /// The captured stdout text, decoded from ``stdoutData`` as UTF-8.
    ///
    /// Invalid UTF-8 sequences are replaced with U+FFFD, so this never fails. Use
    /// ``validatedText(_:)`` when invalid bytes must be detected instead. The text is decoded on each access, so keep it in a local when reading it
    /// repeatedly. Setting this property replaces ``stdoutData`` with the UTF-8 bytes of the new
    /// value.
    ///
    /// Empty when the command produced no stdout, when stdout was routed to
    /// ``OutputDestination/discard``, or when stdout was routed to
    /// ``OutputDestination/file(path:append:)``.
    public var stdout: String {
        get { String(decoding: stdoutData, as: UTF8.self) }
        set { stdoutData = Data(newValue.utf8) }
    }

    /// The captured stderr text, decoded from ``stderrData`` as UTF-8.
    ///
    /// Decoding behaves like ``stdout``. Empty when the command produced no stderr or when stderr
    /// was routed elsewhere via ``OutputDestination``.
    public var stderr: String {
        get { String(decoding: stderrData, as: UTF8.self) }
        set { stderrData = Data(newValue.utf8) }
    }

    /// The process exit status code.
    ///
    /// `0` indicates success; any non-zero value indicates failure. When using
    /// ``Command/run(in:)`` or any typed command family's `run()`, a non-zero exit raises
    /// ``ShellError/exitFailure(command:output:)-enum.case`` rather than returning a `ShellOutput` for
    /// the caller to inspect.
    public var exitCode: Int32

    /// Indicates whether the command exited successfully (``exitCode`` equals zero).
    public var isSuccess: Bool {
        exitCode == 0
    }

    /// Creates a shell output value from captured text and an exit code.
    ///
    /// Useful for constructing ``MockExecutor`` responses in tests or for synthesizing values in
    /// custom executors.
    ///
    /// - Parameters:
    ///   - stdout: The stdout text to expose. Defaults to `""`.
    ///   - stderr: The stderr text to expose. Defaults to `""`.
    ///   - exitCode: The process exit status code. Use `0` to represent success.
    public init(stdout: String = "", stderr: String = "", exitCode: Int32) {
        self.init(stdoutData: Data(stdout.utf8), stderrData: Data(stderr.utf8), exitCode: exitCode)
    }

    /// Creates a shell output value from captured bytes and an exit code.
    ///
    /// Use this to synthesize binary or non-UTF-8 output, for example in a ``MockExecutor``
    /// handler:
    ///
    /// ```swift
    /// let executor = MockExecutor { _, _ in
    ///     ShellOutput(stdoutData: Data([0x1F, 0x8B]), exitCode: 0)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - stdoutData: The stdout bytes to expose.
    ///   - stderrData: The stderr bytes to expose. Defaults to empty.
    ///   - exitCode: The process exit status code. Use `0` to represent success.
    public init(stdoutData: Data, stderrData: Data = Data(), exitCode: Int32) {
        self.stdoutData = stdoutData
        self.stderrData = stderrData
        self.exitCode = exitCode
    }
}

extension ShellOutput {
    /// Returns a captured stream decoded strictly as UTF-8, or `nil` when it contains invalid bytes.
    ///
    /// Use this instead of the lossy ``stdout`` / ``stderr`` views when replacement characters
    /// must not slip into parsed values:
    ///
    /// ```swift
    /// let output = try await Command("git", arguments: "ls-files").run(in: context)
    /// guard let files = output.validatedText() else {
    ///     throw MyError.nonUTF8Path
    /// }
    /// ```
    ///
    /// - Parameter stream: The stream to decode. Defaults to ``StreamKind/stdout``.
    /// - Returns: The decoded text, or `nil` if the bytes are not valid UTF-8.
    public func validatedText(_ stream: StreamKind = .stdout) -> String? {
        String(validating: stream == .stdout ? stdoutData : stderrData, as: UTF8.self)
    }

    /// Returns stdout decoded strictly as UTF-8 for typed parsers.
    ///
    /// Typed families that parse paths or names out of stdout use this instead of the lossy
    /// ``stdout`` so invalid bytes surface as an error rather than as U+FFFD in parsed values.
    ///
    /// - Throws: ``ShellError/decodingError(command:stream:)-enum.case`` when stdout is not valid UTF-8.
    func validatedStdout(for command: Command) throws -> String {
        guard let text = validatedText(.stdout) else {
            throw ShellError.decodingError(command: CommandSnapshot(command), stream: .stdout)
        }
        return text
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
