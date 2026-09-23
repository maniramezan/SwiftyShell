#if Git
import Foundation
@testable import SwiftyShell

extension ShellContext {
    /// A context for real git integration tests that ignores the developer's global and system git
    /// configuration.
    ///
    /// Settings such as `commit.gpgsign`, hooks, or templates otherwise leak into test repositories,
    /// which makes `git commit` fail intermittently on machines with signing enabled and behave
    /// differently from CI.
    static func isolatedGit() -> ShellContext {
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environment["GIT_CONFIG_NOSYSTEM"] = "1"
        return ShellContext(environment: environment)
    }
}
#endif
