/// A POSIX file mode rendered for commands like ``Mkdir`` and ``Chmod``.
///
/// Prefer the typed initializer when you want readable owner/group/other
/// permissions without memorizing octal values:
///
/// ```swift
/// let directoryMode = FileMode(
///     owner: [.read, .write, .execute],
///     group: [.read, .execute],
///     other: [.read, .execute]
/// )
///
/// let fileMode = FileMode(
///     owner: [.read, .write],
///     group: [.read],
///     other: [.read]
/// )
/// ```
///
/// Octal construction remains available when you already have a numeric mode:
///
/// ```swift
/// let executable = FileMode.octal(0o755)
/// let regularFile = FileMode.octal(0o644)
/// ```
public struct FileMode: Sendable, Equatable, Hashable {
    /// Permission bits for one permission class such as owner, group, or other.
    public struct PermissionSet: OptionSet, Sendable, Hashable {
        /// The bitmask raw value for the permission set.
        public let rawValue: UInt8

        /// Read permission (`4`).
        public static let read = Self(rawValue: 0b100)

        /// Write permission (`2`).
        public static let write = Self(rawValue: 0b010)

        /// Execute permission (`1`).
        public static let execute = Self(rawValue: 0b001)

        /// Creates a permission set from bitmask flags.
        ///
        /// - Parameter rawValue: The bitmask combining read, write, and execute.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// Special permission bits that occupy the optional leading octal digit.
    public struct SpecialBits: OptionSet, Sendable, Hashable {
        /// The bitmask raw value for the special mode bits.
        public let rawValue: UInt8

        /// Sticky bit (`1`).
        public static let sticky = Self(rawValue: 0b001)

        /// Set-group-ID bit (`2`).
        public static let setGroupID = Self(rawValue: 0b010)

        /// Set-user-ID bit (`4`).
        public static let setUserID = Self(rawValue: 0b100)

        /// Creates a special-bits set from bitmask flags.
        ///
        /// - Parameter rawValue: The bitmask combining sticky, setgid, and setuid.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// The shell-ready mode string, such as `755` or `644`.
    public let rawValue: String

    private init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a mode from typed owner, group, and other permissions.
    ///
    /// The last three octal digits represent owner, group, and other
    /// permissions. Within each digit, `4` means read, `2` means write, and `1`
    /// means execute. For example, owner `[.read, .write, .execute]`, group
    /// `[.read, .execute]`, and other `[.read, .execute]` renders as `755`.
    ///
    /// - Parameter owner: Permissions for the file owner.
    /// - Parameter group: Permissions for the owning group.
    /// - Parameter other: Permissions for everyone else.
    /// - Parameter special: Optional leading special bits such as sticky,
    ///   setgid, and setuid.
    public init(
        owner: PermissionSet,
        group: PermissionSet,
        other: PermissionSet,
        special: SpecialBits = []
    ) {
        let digits = [
            String(owner.rawValue, radix: 8),
            String(group.rawValue, radix: 8),
            String(other.rawValue, radix: 8),
        ]

        if special.isEmpty {
            self.rawValue = digits.joined()
        } else {
            self.rawValue = String(special.rawValue, radix: 8) + digits.joined()
        }
    }

    /// Creates a mode from standard octal permission bits.
    ///
    /// In values like `0o755`, the last three digits represent owner, group,
    /// and other permissions. Each digit is a sum of `4` (read), `2` (write),
    /// and `1` (execute). A leading fourth digit may be used for special bits
    /// such as sticky, setgid, and setuid.
    ///
    /// - Parameter value: The octal permission bits to render for the shell.
    /// - Returns: A file mode whose ``rawValue`` matches the octal text passed
    ///   to tools like `mkdir -m` and `chmod`.
    public static func octal(_ value: UInt16) -> Self {
        Self(rawValue: String(value, radix: 8))
    }
}
