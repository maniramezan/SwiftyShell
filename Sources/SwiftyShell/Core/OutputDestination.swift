import Foundation

/// Controls how a command stream is handled during execution.
///
/// Pass an ``OutputDestination`` to ``Command/stdout(_:)`` or ``Command/stderr(_:)``
/// to change where each stream goes:
///
/// Capture is the default and keeps stream contents in memory on ``ShellOutput``:
///
/// ```swift
/// let output = try await Command("ls").run(in: context)
/// print(output.stdout)
/// ```
///
/// Discard a stream when the caller intentionally does not need it:
///
/// ```swift
/// try await Command("make", arguments: "clean")
///     .stderr(.discard)
///     .run(in: context)
/// ```
///
/// Write to a file when output can be large or should become a build artifact:
///
/// ```swift
/// try await Command("swift", arguments: "build", "--verbose")
///     .stdout(.file(path: "/tmp/build.log", append: false))
///     .run(in: context)
/// ```
///
/// Append mode preserves existing file contents:
///
/// ```swift
/// try await Command("swift", arguments: "build")
///     .stderr(.file(path: "/tmp/build.log", append: true))
///     .run(in: context)
/// ```
///
/// Stream a long build live while still capturing it for parsing:
///
/// ```swift
/// let output = try await Command("./gradlew", arguments: "bundleRelease")
///     .stdout(.tee)
///     .run(in: context)
/// // Console shows progress during the build; output.stdout still holds the full log.
/// ```
public enum OutputDestination: Sendable, Equatable {
    /// Captures the stream in memory and returns it via ``ShellOutput/stdout`` or
    /// ``ShellOutput/stderr``.
    ///
    /// This is the default. Captured bytes count toward ``ShellContext/defaultOutputLimit`` (or
    /// the per-command override applied via ``Command/outputLimit(_:)``); exceeding that limit
    /// raises ``ShellError/outputLimitExceeded(command:limit:partialOutput:)-enum.case``.
    case capture

    /// Discards the stream entirely.
    ///
    /// Discarded bytes never reach memory and do not contribute to the output limit. Use this
    /// for streams whose content is intentionally unwanted (for example noisy progress
    /// messages).
    ///
    /// For ``Command/run(in:)`` and pipelines, the built-in executor points the child's stream at
    /// the null device, so the bytes never pass through the calling process. A spawned process
    /// still delivers them to its live ``SpawnedProcess/standardOutput`` stream without retaining
    /// them.
    case discard

    /// Writes the stream to a file at `path`.
    ///
    /// File destinations bypass in-memory capture, making them well-suited to large outputs such
    /// as build logs or generated artifacts. The corresponding field on ``ShellOutput`` is left
    /// empty when this destination is used.
    ///
    /// For ``Command/run(in:)`` and pipelines, the built-in executor opens the file the way shell
    /// redirection does (created with mode `0666` less the umask; truncated, or opened with
    /// `O_APPEND`) and hands the descriptor to the child, which writes to it directly. Writes from
    /// both streams in append mode never overwrite each other, and output from background
    /// descendants that outlive the command still reaches the file. A spawned process writes the
    /// file from the calling process so the same bytes can feed its live stream.
    ///
    /// - Parameters:
    ///   - path: The absolute or relative file path to write to. Relative paths are resolved
    ///     against the executor's working directory at spawn time.
    ///   - append: When `true`, output is appended to any existing file contents. When `false`,
    ///     the file is truncated before writing.
    case file(path: String, append: Bool)

    /// Streams the stream to the parent process's stdout (for ``StreamKind/stdout``) or
    /// stderr (for ``StreamKind/stderr``) as bytes arrive, while ALSO capturing them in
    /// memory for ``ShellOutput``. Use for long-running commands where live progress matters
    /// but the output is also needed for parsing.
    ///
    /// Captured bytes count toward the output limit exactly like ``capture``. Live bytes are
    /// written to the inherited FD immediately and are not buffered until exit.
    case tee

    /// Streams to the selected parent stream while capturing the original child stream.
    ///
    /// Use `.stdout(.teeTo(.stderr))` to keep the parent's stdout available for JSON.
    /// Captured bytes still count toward the command's output limit.
    /// - Parameter stream: The parent stream that receives live bytes.
    case teeTo(StreamKind)

    /// Writes a complete log while retaining only the last `tailBytes` bytes of this stream.
    ///
    /// Unlike the hard output limit, filling this tail does not terminate the command. Retained
    /// bytes still count toward the shared command output limit. A tail may start within a UTF-8
    /// character; use raw ``ShellOutput`` data for exact bytes. For spawned processes, the tail is
    /// retained only with `spawn(captureOutput: true)`.
    ///
    /// The tail is updated before the log file is written, so once a byte appears in the log the
    /// tail is guaranteed to already contain it.
    ///
    /// - Parameters:
    ///   - path: Log path, resolved against the command's working directory.
    ///   - append: Whether to append to an existing log instead of truncating it.
    ///   - tailBytes: Maximum bytes retained for this stream; zero retains nothing; must be nonnegative.
    ///   - tee: Optional parent stream to receive live bytes as well as the file.
    case log(path: String, append: Bool, tailBytes: Int, tee: StreamKind? = nil)

    var fileDestination: (path: String, append: Bool)? {
        switch self {
        case let .file(path, append), let .log(path, append, _, _): (path, append)
        default: nil
        }
    }

    func validate() throws {
        if case let .log(_, _, tailBytes, _) = self, tailBytes < 0 {
            throw ShellError.invalidConfiguration(description: "Log tail size must be nonnegative")
        }
    }
}
