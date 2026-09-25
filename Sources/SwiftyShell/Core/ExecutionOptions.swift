import Foundation

/// The execution overrides shared by ``Command`` and ``ToolConfiguration``.
///
/// Both types expose these as read-only properties and update them through fluent methods; keeping
/// the storage and the environment rules in one place means the two cannot drift apart.
struct ExecutionOptions: Sendable, Equatable {
    var executableOverride: String?
    var environmentOverrides: [String: String] = [:]
    var unsetEnvironmentVariables: Set<String> = []
    var workingDirectoryOverride: String?
    var timeoutOverride: Duration?
    var outputLimitOverride: Int?

    /// Sets or replaces environment variables; a variable set here is no longer unset.
    mutating func setEnvironment(_ values: [String: String]) {
        environmentOverrides.merge(values) { _, new in new }
        unsetEnvironmentVariables.subtract(values.keys)
    }

    /// Removes environment variables from the child's environment, dropping any override for them.
    mutating func unsetEnvironment(_ names: some Sequence<String>) {
        for name in names {
            environmentOverrides.removeValue(forKey: name)
            unsetEnvironmentVariables.insert(name)
        }
    }
}
