import Foundation

/// Controls how a command stream is handled during execution.
///
/// Pass an ``OutputDestination`` to ``Command/stdout(_:)`` or ``Command/stderr(_:)``
/// to change where each stream goes:
///
/// ```swift
/// // Capture stdout (default)
/// let output = try await Command("ls").run(in: context)
/// print(output.stdout)
///
/// // Discard stderr to suppress noise
/// let result = try await Command("make", "clean")
///     .stderr(.discard)
///     .run(in: context)
///
/// // Write stdout to a log file (overwrite)
/// try await Command("xcodebuild", "-scheme", "App")
///     .stdout(.file(path: "/tmp/build.log", append: false))
///     .run(in: context)
///
/// // Append stderr to an existing log file
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
