import Foundation

/// A reusable asynchronous workflow that can be transformed and composed.
///
/// ``Workflow`` wraps an async operation and supports `map`, `flatMap`, and
/// `require` transformations before the result is materialized by calling `run()`.
///
/// Create a workflow when you want to describe work first and run it later. This example turns raw
/// command output into a trimmed commit hash before the caller awaits the workflow.
///
/// ```swift
/// let shaWorkflow: Workflow<String> = Workflow {
///     let output = try await Command("git", arguments: "rev-parse", "HEAD").run(in: context)
///     return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
/// }
///
/// let sha = try await shaWorkflow.run()
/// ```
///
/// Use `require` to stop later workflow steps when a precondition fails. Here the branch name is
/// read only if the working tree is clean.
///
/// ```swift
/// let branchWorkflow = Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .require(\.state, equals: .noChanges, else: MyError.dirtyTree)
///     .map(\.branch)
///
/// let branch = try await branchWorkflow.run()
/// ```
///
/// > Important: ``Workflow`` is **single-use** — call ``run()`` exactly once.
/// > Rebuild from the source client if you need to run the same operation again.
public struct Workflow<Value>: Sendable {
    private let operation: @Sendable () async throws -> Value

    /// Creates a workflow from an async throwing operation.
    ///
    /// The operation is captured but not started. It runs only when ``run()`` is awaited; until
    /// then, transformations such as ``map(_:)-((Value)->T)``, ``flatMap(_:)``, ``then(_:)``, and
    /// ``require(_:else:)`` compose new workflows that wrap the original.
    ///
    /// - Parameter operation: The async throwing closure that produces the workflow's value
    ///   when ``run()`` is invoked.
    public init(_ operation: @escaping @Sendable () async throws -> Value) {
        self.operation = operation
    }

    /// Runs the workflow and returns its value.
    ///
    /// ``Workflow`` is `consuming` and **single-use** — call this method exactly once. To run an
    /// equivalent operation again, rebuild the workflow from its source (for example by calling
    /// the typed client method that returned it).
    ///
    /// - Returns: The value produced by the captured operation.
    /// - Throws: Whatever the operation throws (typically ``ShellError``).
    public consuming func run() async throws -> Value {
        try await operation()
    }

    /// Returns a new workflow that transforms this workflow's output with a synchronous closure.
    ///
    /// The returned workflow runs `self` first, then applies `transform` on the result. If
    /// `transform` throws, the new workflow re-throws the error from ``run()``.
    ///
    /// ```swift
    /// let trimmedWorkflow = Workflow { try await Command("git", arguments: "rev-parse", "HEAD").run().stdout }
    ///     .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// ```
    ///
    /// - Parameter transform: The synchronous, throwing transform applied to the workflow's
    ///   output.
    /// - Returns: A new ``Workflow`` whose value is `transform`'s result.
    public func map<T>(
        _ transform: @escaping @Sendable (Value) throws -> T
    ) -> Workflow<T> {
        let op = operation
        return Workflow<T> {
            try transform(try await op())
        }
    }

    /// Returns a new workflow that projects this workflow's output through a key path.
    ///
    /// Sugar for `map { $0[keyPath: keyPath] }`. Useful when you only need a single field of a
    /// structured result, such as `.map(\.branch)` on a ``GitStatus`` workflow.
    ///
    /// - Parameter keyPath: The key path to project.
    /// - Returns: A new ``Workflow`` whose value is the projected field.
    public func map<T>(_ keyPath: KeyPath<Value, T>) -> Workflow<T> {
        let keyPath = SendableKeyPath(keyPath)
        return map { $0[keyPath: keyPath.value] }
    }

    /// Returns a new workflow that chains into another workflow produced from this workflow's
    /// output.
    ///
    /// Use this to express dependent steps where the next workflow depends on the previous
    /// step's value (for example, fetch a branch name, then push that branch).
    ///
    /// - Parameter transform: An async closure that receives this workflow's output and returns
    ///   the next workflow to run.
    /// - Returns: A new ``Workflow`` whose value is the chained workflow's value.
    public func flatMap<T>(
        _ transform: @escaping @Sendable (Value) async throws -> Workflow<T>
    ) -> Workflow<T> {
        let op = operation
        return Workflow<T> {
            let value = try await op()
            return try await transform(value).run()
        }
    }

    /// Returns a new workflow that runs an additional async transform after this workflow
    /// succeeds.
    ///
    /// Equivalent to ``map(_:)-((Value)->T)`` but accepts an `async` closure. Use this when the next
    /// step is asynchronous but does not itself produce a ``Workflow``.
    ///
    /// - Parameter next: An async, throwing closure that receives this workflow's output and
    ///   returns the next value.
    /// - Returns: A new ``Workflow`` whose value is `next`'s result.
    public func then<T>(
        _ next: @escaping @Sendable (Value) async throws -> T
    ) -> Workflow<T> {
        let op = operation
        return Workflow<T> {
            let value = try await op()
            return try await next(value)
        }
    }

    /// Returns a new workflow that aborts unless this workflow's output satisfies a predicate.
    ///
    /// When `predicate` returns `false`, the returned workflow throws the result of `error`
    /// instead of forwarding the value. Use this to enforce preconditions before running
    /// downstream steps — for example, refusing to push when the working tree is dirty.
    ///
    /// - Parameters:
    ///   - predicate: A throwing closure that returns `true` to allow the value through.
    ///   - error: An autoclosure producing the error to throw when `predicate` returns `false`.
    /// - Returns: A new ``Workflow`` that re-emits this workflow's value or throws the
    ///   precondition error.
    public func require(
        _ predicate: @escaping @Sendable (Value) throws -> Bool,
        else error: @autoclosure @escaping @Sendable () -> Error
    ) -> Workflow<Value> {
        let op = operation
        return Workflow<Value> {
            let value = try await op()
            guard try predicate(value) else {
                throw error()
            }
            return value
        }
    }

    /// Returns a new workflow that aborts unless a key path on this workflow's output equals an
    /// expected value.
    ///
    /// Sugar for ``require(_:else:)`` with an `==` predicate.
    ///
    /// ```swift
    /// .require(\.state, equals: .noChanges, else: MyError.dirtyTree)
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: The key path to project from this workflow's output.
    ///   - expected: The value the projected field must equal.
    ///   - error: An autoclosure producing the error to throw when the projected field does not
    ///     match `expected`.
    /// - Returns: A new ``Workflow`` that re-emits this workflow's value or throws the
    ///   precondition error.
    public func require<T: Equatable & Sendable>(
        _ keyPath: KeyPath<Value, T>,
        equals expected: T,
        else error: @autoclosure @escaping @Sendable () -> Error
    ) -> Workflow<Value> {
        let keyPath = SendableKeyPath(keyPath)
        return require({ $0[keyPath: keyPath.value] == expected }, else: error())
    }
}

private struct SendableKeyPath<Root, Value>: @unchecked Sendable {
    let value: KeyPath<Root, Value>

    init(_ value: KeyPath<Root, Value>) {
        self.value = value
    }
}
