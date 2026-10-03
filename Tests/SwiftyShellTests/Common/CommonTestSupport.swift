import Foundation

/// Shared helpers for the per-family Common test files.
///
/// Scratch directories come from `TestCommons.TemporaryDirectory`.
///
/// Lives outside any `#if` gate so it remains available whenever any single
/// Common family trait is enabled. The helpers themselves do not reference any
/// command family symbols.
enum CommonTestSupport {
    /// Strips macOS `/private` prefixes so resolved paths can be compared to user-facing ones.
    static func normalizePath(_ path: String) -> String {
        if path.hasPrefix("/private/var/") {
            return String(path.dropFirst("/private".count))
        }
        return path
    }
}
