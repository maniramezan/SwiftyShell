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
    /// raises ``ShellError/outputLimitExceeded(command:limit:partialOutput:)``.
    case capture

    /// Discards the stream entirely.
    ///
    /// Discarded bytes never reach memory and do not contribute to the output limit. Use this
    /// for streams whose content is intentionally unwanted (for example noisy progress
    /// messages).
    case discard

    /// Writes the stream to a file at `path`.
    ///
    /// File destinations bypass in-memory capture, making them well-suited to large outputs such
    /// as build logs or generated artifacts. The corresponding field on ``ShellOutput`` is left
    /// empty when this destination is used.
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
}
