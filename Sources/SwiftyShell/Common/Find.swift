#if Find
import Foundation

/// A portable file type accepted by ``FindExpression/type(_:)``.
public enum FindFileType: String, Sendable, Equatable, Hashable {
    /// A block special device.
    case blockDevice = "b"

    /// A character special device.
    case characterDevice = "c"

    /// A directory.
    case directory = "d"

    /// A regular file.
    case regularFile = "f"

    /// A symbolic link when links are not being followed.
    case symbolicLink = "l"

    /// A named pipe (FIFO).
    case namedPipe = "p"

    /// A Unix-domain socket.
    case socket = "s"
}

/// A typed expression evaluated by ``Find`` for each visited path.
///
/// The model intentionally contains only primaries and operators shared by the current macOS/BSD
/// and GNU implementations. Values become separate argv elements, so patterns and paths are never
/// interpreted by a shell.
///
/// ```swift
/// let expression = FindExpression.name("*.swift")
///     .and(.type(.regularFile))
///     .and(.print)
///
/// let output = try await Find(context: context)
///     .root("Sources")
///     .expression(expression)
///     .run()
/// ```
public indirect enum FindExpression: Sendable, Equatable, Hashable {
    /// Matches the final path component against a shell pattern using `-name`.
    case name(String)

    /// Matches the complete traversed path against a shell pattern using `-path`.
    case path(String)

    /// Matches entries of the specified file type using `-type`.
    case type(FindFileType)

    /// Applies tests and actions only at or below the specified traversal depth.
    ///
    /// Although spelled as a primary, `-mindepth` affects the complete traversal expression on
    /// both supported implementations.
    case minimumDepth(UInt)

    /// Prevents descent below the specified traversal depth.
    ///
    /// Although spelled as a primary, `-maxdepth` affects the complete traversal expression on
    /// both supported implementations.
    case maximumDepth(UInt)

    /// Negates an expression using the portable `!` operator.
    case not(FindExpression)

    /// Combines two expressions with short-circuiting logical AND.
    case and(FindExpression, FindExpression)

    /// Combines two expressions with short-circuiting logical OR.
    case or(FindExpression, FindExpression)

    /// Prints each matching path followed by a newline.
    case print

    /// Prints each matching path followed by an ASCII NUL byte.
    case print0

    /// Returns a parenthesized conjunction of this expression and another expression.
    ///
    /// - Parameter other: The expression evaluated only when this expression is true.
    /// - Returns: A new logical AND expression.
    public func and(_ other: Self) -> Self {
        .and(self, other)
    }

    /// Returns a parenthesized disjunction of this expression and another expression.
    ///
    /// - Parameter other: The expression evaluated only when this expression is false.
    /// - Returns: A new logical OR expression.
    public func or(_ other: Self) -> Self {
        .or(self, other)
    }

    /// Returns this expression wrapped in logical negation.
    public func negated() -> Self {
        .not(self)
    }

    fileprivate var arguments: [String] {
        switch self {
        case .name(let pattern):
            return ["-name", pattern]
        case .path(let pattern):
            return ["-path", pattern]
        case .type(let type):
            return ["-type", type.rawValue]
        case .minimumDepth(let depth):
            return ["-mindepth", String(depth)]
        case .maximumDepth(let depth):
            return ["-maxdepth", String(depth)]
        case .not(let expression):
            return ["!", "("] + expression.arguments + [")"]
        case .and(let lhs, let rhs):
            return ["("] + lhs.arguments + ["-and"] + rhs.arguments + [")"]
        case .or(let lhs, let rhs):
            return ["("] + lhs.arguments + ["-or"] + rhs.arguments + [")"]
        case .print:
            return ["-print"]
        case .print0:
            return ["-print0"]
        }
    }
}

/// A portable, typed wrapper for the `find` command.
///
/// ``Find`` targets the common behavior of the current macOS/BSD and GNU implementations. It
/// supports roots, name/path/type/depth tests, boolean composition, and newline- or NUL-delimited
/// output. It deliberately omits shell execution actions such as `-exec`.
///
/// ```swift
/// let output = try await Find(context: context)
///     .root("Sources")
///     .expression(.name("*.swift").and(.type(.regularFile)).and(.print0))
///     .run()
/// ```
public struct Find: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `find` command family bound to a shell context.
    ///
    /// With no configured roots, ``command()`` emits `.` explicitly for consistent BSD/GNU
    /// behavior. With no expression, `find` uses its standard implicit newline printing action.
    ///
    /// - Parameter context: The shell context used to execute the command.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Find`` value with the updated configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes stdout to the given destination.
    ///
    /// - Parameter destination: Where the executor should send matching paths.
    /// - Returns: A new ``Find`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes stderr to the given destination.
    ///
    /// - Parameter destination: Where the executor should send diagnostics.
    /// - Returns: A new ``Find`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy with one additional traversal root.
    ///
    /// Relative roots beginning with `-`, `!`, or `(` are emitted with a `./` prefix. BSD offers
    /// `-f` for such paths while GNU does not; qualification is the portable way to keep the root
    /// from being parsed as an expression. Absolute and already-qualified paths are unchanged.
    ///
    /// - Parameter path: The file or directory at which traversal starts.
    /// - Returns: A new ``Find`` value with the root appended.
    public func root(_ path: String) -> Self {
        copy(roots: state.roots + [Self.portableRoot(path)])
    }

    /// Returns a copy with multiple traversal roots appended in order.
    ///
    /// Each root receives the same portable qualification described by ``root(_:)``.
    ///
    /// - Parameter paths: The traversal roots to append.
    /// - Returns: A new ``Find`` value with the roots appended.
    public func roots(_ paths: [String]) -> Self {
        copy(roots: state.roots + paths.map(Self.portableRoot))
    }

    /// Returns a copy with the expression evaluated for every visited path.
    ///
    /// Calling this method again replaces the previous expression.
    ///
    /// - Parameter value: The typed tests, operators, and output actions to evaluate.
    /// - Returns: A new ``Find`` value with the expression applied.
    public func expression(_ value: FindExpression) -> Self {
        copy(expression: value)
    }

    /// Builds the raw `find` command represented by the current builder state.
    ///
    /// Every root, operator, primary, pattern, and action is emitted as a separate argv element.
    /// No shell parses or expands any supplied value.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = state.roots.isEmpty ? ["."] : state.roots
        if let expression = state.expression {
            arguments.append(contentsOf: expression.arguments)
        }

        let base = Command("find")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private static func portableRoot(_ path: String) -> String {
        guard let first = path.first, first == "-" || first == "!" || first == "(" else {
            return path
        }
        return "./\(path)"
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        roots: [String]? = nil,
        expression: FindExpression? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                roots: roots ?? state.roots,
                expression: expression ?? state.expression
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let roots: [String]
    let expression: FindExpression?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        roots: [String] = [],
        expression: FindExpression? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.roots = roots
        self.expression = expression
    }
}
#endif
