#if Git
import Foundation

/// A git-specific workflow wrapper that preserves git-oriented chaining.
///
/// ``GitStatusWorkflow`` is returned by ``Git/status()`` and supports the same
/// `map`, `require`, `pull`, and `fetch` chains as ``Workflow``, while carrying
/// the git client reference needed to start follow-up operations:
///
/// Use ``require(_:equals:else:)`` to stop a workflow before a mutating follow-up command runs. In
/// this example, `pull()` only runs if the repository has no staged, unstaged, or untracked
/// changes; otherwise the workflow throws `MyError.dirtyTree`.
///
/// ```swift
/// let result = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .require(\.state, equals: .noChanges, else: MyError.dirtyTree)
///     .pull()    // Runs only after the status requirement succeeds.
///     .run()
/// ```
///
/// If you only need the parsed status, run the workflow directly. The result is a ``GitStatus``
/// value rather than raw `git status` output.
///
/// ```swift
/// let status: GitStatus = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .run()
/// ```
public struct GitStatusWorkflow: Sendable {
    let git: Git
    let workflow: Workflow<GitStatus>

    /// Runs the underlying git status workflow and returns the parsed result.
    ///
    /// `consuming` to match ``Workflow/run()``. Workflow values are copyable, and running a copy
    /// re-executes every queued step.
    ///
    /// - Returns: The parsed ``GitStatus`` value produced by `git status --porcelain=v2 --branch`.
    /// - Throws: ``ShellError`` if `git` exits non-zero, the output cannot be parsed, or any
    ///   `require` predicate added earlier in the chain fails.
    public consuming func run() async throws -> GitStatus {
        try await workflow.run()
    }

    /// Maps the parsed git status value using a synchronous transform.
    ///
    /// Drops the git client reference and produces a plain ``Workflow`` carrying the
    /// transformed value. Use this once you no longer need to chain another typed git
    /// operation onto the result.
    ///
    /// - Parameter transform: A pure function applied to the parsed ``GitStatus``.
    /// - Returns: A ``Workflow`` that produces the transformed value when run.
    public func map<T>(
        _ transform: @escaping @Sendable (GitStatus) throws -> T
    ) -> Workflow<T> {
        workflow.map(transform)
    }

    /// Maps the parsed git status value using a key path.
    ///
    /// Convenience for projecting a single field (e.g. `status.map(\.branch)`). Like the
    /// closure overload, the result is a plain ``Workflow``.
    ///
    /// - Parameter keyPath: The key path to extract from the parsed ``GitStatus``.
    /// - Returns: A ``Workflow`` that produces the projected value when run.
    public func map<T>(_ keyPath: KeyPath<GitStatus, T>) -> Workflow<T> {
        workflow.map(keyPath)
    }

    /// Requires the parsed git status to satisfy a predicate before the workflow continues.
    ///
    /// Lets the workflow keep its ``GitStatusWorkflow`` shape so subsequent calls like
    /// ``pull()`` and ``fetch()`` remain available. If the predicate returns `false` or throws,
    /// the workflow rejects with the supplied error.
    ///
    /// - Parameters:
    ///   - predicate: A pure check applied to the parsed ``GitStatus``.
    ///   - error: The error thrown when the predicate is unsatisfied. Defaults to
    ///     ``ShellError/workflowConditionFailed(description:)``.
    /// - Returns: A new ``GitStatusWorkflow`` that fails fast when the predicate does not hold.
    public func require(
        _ predicate: @escaping @Sendable (GitStatus) throws -> Bool,
        else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(
            description: "Git workflow condition failed"
        )
    ) -> GitStatusWorkflow {
        GitStatusWorkflow(git: git, workflow: workflow.require(predicate, else: error()))
    }

    /// Requires a key path on the parsed git status to equal an expected value.
    ///
    /// Sugar over ``require(_:else:)`` for the common case of comparing one field to a literal
    /// (e.g. `require(\.state, equals: .noChanges)`).
    ///
    /// - Parameters:
    ///   - keyPath: The key path to read from the parsed ``GitStatus``.
    ///   - expected: The required value at that key path.
    ///   - error: The error thrown when the value does not match. Defaults to
    ///     ``ShellError/workflowConditionFailed(description:)``.
    /// - Returns: A new ``GitStatusWorkflow`` that fails fast when the values differ.
    public func require<T: Equatable & Sendable>(
        _ keyPath: KeyPath<GitStatus, T>,
        equals expected: T,
        else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(
            description: "Git workflow condition failed"
        )
    ) -> GitStatusWorkflow {
        GitStatusWorkflow(git: git, workflow: workflow.require(keyPath, equals: expected, else: error()))
    }

    /// Continues the workflow with `git pull` once the status step succeeds.
    ///
    /// Use after ``require(_:else:)`` to gate the pull on a clean working tree, a specific
    /// branch, or any other predicate.
    ///
    /// - Returns: A ``Workflow`` that produces a ``GitPullResult`` describing the post-pull
    ///   branch state.
    public func pull() -> Workflow<GitPullResult> {
        let git = git
        return workflow.flatMap { _ in git.pull() }
    }

    /// Continues the workflow with `git fetch` once the status step succeeds.
    ///
    /// The remote is auto-detected: `origin` if present, otherwise the first configured remote.
    ///
    /// - Returns: A ``Workflow`` that produces a ``GitFetchResult`` describing the fetched remote.
    public func fetch() -> Workflow<GitFetchResult> {
        let git = git
        return workflow.flatMap { _ in git.fetch() }
    }
}
#endif
