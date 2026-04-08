import Foundation

/// A git-specific workflow wrapper that preserves git-oriented chaining.
///
/// ``GitStatusWorkflow`` is returned by ``Git/status()`` and supports the same
/// `map`, `require`, `pull`, and `fetch` chains as ``Workflow``, while carrying
/// the git client reference needed to start follow-up operations:
///
/// ```swift
/// // Check status and conditionally pull
/// let result = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .require(\.state, equals: .noChanges, else: MyError.dirtyTree)
///     .pull()
///     .run()
///
/// // Just read status
/// let status: GitStatus = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .run()
/// ```
public struct GitStatusWorkflow: Sendable {
    let git: Git
    let workflow: Workflow<GitStatus>

    /// Runs the underlying git status workflow.
    public consuming func run() async throws -> GitStatus {
        try await workflow.run()
    }

    /// Maps the git status value using a synchronous transform.
    public func map<T>(
        _ transform: @escaping @Sendable (GitStatus) throws -> T
    ) -> Workflow<T> {
        workflow.map(transform)
    }

    /// Maps the git status value using a key path.
    public func map<T>(_ keyPath: KeyPath<GitStatus, T>) -> Workflow<T> {
        workflow.map(keyPath)
    }

    /// Requires the git status to satisfy a predicate.
    public func require(
        _ predicate: @escaping @Sendable (GitStatus) throws -> Bool,
        else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(description: "Git workflow condition failed")
    ) -> GitStatusWorkflow {
        GitStatusWorkflow(git: git, workflow: workflow.require(predicate, else: error()))
    }

    /// Requires a git status key path to equal an expected value.
    public func require<T: Equatable & Sendable>(
        _ keyPath: KeyPath<GitStatus, T>,
        equals expected: T,
        else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(description: "Git workflow condition failed")
    ) -> GitStatusWorkflow {
        GitStatusWorkflow(git: git, workflow: workflow.require(keyPath, equals: expected, else: error()))
    }

    /// Continues the workflow with `git pull` if status succeeds.
    public func pull() -> Workflow<GitPullResult> {
        let git = git
        return workflow.flatMap { _ in git.pull() }
    }

    /// Continues the workflow with `git fetch` if status succeeds.
    public func fetch() -> Workflow<GitFetchResult> {
        let git = git
        return workflow.flatMap { _ in git.fetch() }
    }
}
