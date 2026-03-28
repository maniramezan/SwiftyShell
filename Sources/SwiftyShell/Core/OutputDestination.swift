import Foundation

/// Controls how a command stream is handled during execution.
public enum OutputDestination: Sendable, Equatable {
    /// Captures the stream in memory and returns it in `ShellOutput`.
    case capture
    /// Discards the stream.
    case discard
    /// Writes the stream to a file, optionally appending.
    case file(path: String, append: Bool)
}
