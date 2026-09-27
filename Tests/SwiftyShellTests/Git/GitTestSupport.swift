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
        // Ignoring the global config also drops any `safe.directory` entry, and git refuses to use a
        // repository whose directory appears owned by another user (as temp directories do in some
        // containers and bind mounts). Environment-supplied config counts as command-line config,
        // which git honors for `safe.directory`.
        environment["GIT_CONFIG_COUNT"] = "1"
        environment["GIT_CONFIG_KEY_0"] = "safe.directory"
        environment["GIT_CONFIG_VALUE_0"] = "*"
        return ShellContext(environment: environment)
    }
}
#endif
