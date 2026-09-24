import Foundation

/// Where a command's standard input comes from.
///
/// Pass an ``InputSource`` to ``Command/stdin(_:)`` to feed a command its input. Without one, a
/// command reads an empty stdin (end of file immediately), so tools that wait for input never block.
///
/// Feed text, for example JSON into `jq`:
///
/// ```swift
/// let output = try await Command("jq", arguments: ".name")
///     .stdin(.string(#"{"name": "SwiftyShell"}"#))
///     .run(in: context)
/// ```
///
/// Feed raw bytes:
///
/// ```swift
/// let digest = try await Command("shasum", arguments: "-a", "256")
///     .stdin(.data(archiveData))
///     .run(in: context)
/// ```
///
/// Read a file, like shell `<` redirection:
///
/// ```swift
/// let lines = try await Command("wc", arguments: "-l")
///     .stdin(.file(path: "Package.swift"))
///     .run(in: context)
/// ```
///
/// In a ``Pipeline``, only the first stage's input source is used; every later stage reads the
/// previous stage's stdout.
public enum InputSource: Sendable, Equatable {
    /// An empty stdin: the command reads end of file immediately. This is the default.
    case none

    /// The given bytes, followed by end of file.
    case data(Data)

    /// The UTF-8 encoding of the given text, followed by end of file.
    case string(String)

    /// The contents of the file at `path`, like shell `<` redirection.
    ///
    /// Relative paths are resolved against the command's effective working directory. A missing or
    /// unreadable file fails the run with ``ShellError/spawnError(command:reason:)``.
    ///
    /// - Parameter path: The absolute or relative path of the file to read.
    case file(path: String)
}

extension InputSource {
    /// A short description for ``Command/debugDescription`` that shows sizes instead of contents.
    var debugSummary: String {
        switch self {
        case .none: "none"
        case let .data(data): "data(\(data.count) bytes)"
        case let .string(text): "string(\(text.utf8.count) bytes)"
        case let .file(path): "file(\(path.debugDescription))"
        }
    }
}
