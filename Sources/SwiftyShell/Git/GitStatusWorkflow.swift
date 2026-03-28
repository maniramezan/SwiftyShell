import Foundation

/// A git-specific workflow wrapper that preserves git-oriented chaining.
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
