/// The executable and argv associated with a command failure.
///
/// Error snapshots retain argument boundaries without retaining environment overrides or stdin.
/// Built-in execution errors also record the resolved executable path.
///
/// ```swift
/// do {
///     _ = try await Command("false").run()
/// } catch ShellError.exitFailure(let command, _) {
///     print(command.executableName, command.arguments ?? [])
/// }
/// ```
public struct CommandSnapshot: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The originally requested executable, or `nil` for a legacy display-only snapshot.
    public let executableName: String?
    /// The argv entries, or `nil` when constructed from a legacy display string.
    public let arguments: [String]?
    /// The resolved executable path when resolution succeeded.
    public let resolvedExecutable: String?
    /// The POSIX-quoted display representation.
    public let displayString: String

    /// Captures the executable and argv without environment values or stdin bytes.
    /// - Parameters:
    ///   - command: The command being described.
    ///   - resolvedExecutable: The resolved executable path, when available.
    public init(_ command: Command, resolvedExecutable: String? = nil) {
        self.executableName = command.executableName
        self.arguments = command.arguments
        self.resolvedExecutable = resolvedExecutable
        self.displayString = command.displayString(using: resolvedExecutable)
    }

    /// Creates a display-only snapshot for errors supplied by custom executors.
    /// - Parameter displayString: Existing display text; it is never parsed as shell syntax.
    public init(displayString: String) {
        self.executableName = nil
        self.arguments = nil
        self.resolvedExecutable = nil
        self.displayString = displayString
    }

    /// The shell-quoted display representation.
    public var description: String { displayString }
    /// The quoted display representation for diagnostics.
    public var debugDescription: String { displayString.debugDescription }
}
