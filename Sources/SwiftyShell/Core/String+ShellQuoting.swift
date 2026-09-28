import Foundation

extension String {
    /// Returns this string quoted as a POSIX shell component when needed for display.
    ///
    /// Only nonempty strings containing ASCII letters, digits, and `@%+=:,./_-` remain
    /// unquoted. Embedded single quotes are escaped between single-quoted segments.
    internal func shellQuoted() -> String {
        if !isEmpty, unicodeScalars.allSatisfy(Self.shellSafeCharacters.contains) {
            return self
        }
        return "'" + replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    private static let shellSafeCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@%+=:,./_-"
    )
}
