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
/// try await Command("make", "clean")
///     .stderr(.discard)
///     .run(in: context)
/// ```
///
/// Write to a file when output can be large or should become a build artifact:
///
/// ```swift
/// try await Command("swift", "build", "--verbose")
///     .stdout(.file(path: "/tmp/build.log", append: false))
///     .run(in: context)
/// ```
///
/// Append mode preserves existing file contents:
///
/// ```swift
/// try await Command("swift", "build")
///     .stderr(.file(path: "/tmp/build.log", append: true))
///     .run(in: context)
/// ```
public enum OutputDestination: Sendable, Equatable {
    /// Captures the stream in memory and returns it in `ShellOutput`.
    case capture
    /// Discards the stream.
    case discard
    /// Writes the stream to a file, optionally appending.
    case file(path: String, append: Bool)
}
