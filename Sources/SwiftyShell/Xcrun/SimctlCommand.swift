import Foundation

/// A typed target accepted by `simctl list`.
public struct SimctlListTarget: Sendable, Equatable, Hashable {
    /// The raw arguments that represent the list target.
    public let arguments: [String]

    /// Creates a `simctl list` target from raw arguments.
    public init(_ arguments: String...) {
        precondition(!arguments.isEmpty, "A simctl list target must include at least one argument.")
        self.arguments = arguments
    }

    private init(arguments: [String]) {
        precondition(!arguments.isEmpty, "A simctl list target must include at least one argument.")
        self.arguments = arguments
    }

    /// Creates a custom list target.
    public static func custom(_ value: String) -> Self {
        Self(arguments: [value])
    }

    /// The `devices` list target.
    public static let devices = Self("devices")
    /// The `devicetypes` list target.
    public static let devicetypes = Self("devicetypes")
    /// The `runtimes` list target.
    public static let runtimes = Self("runtimes")
    /// The `pairs` list target.
    public static let pairs = Self("pairs")
}

/// A typed `simctl` subcommand and its arguments.
public struct SimctlCommand: Sendable, Equatable, Hashable {
    /// The raw arguments that represent the subcommand.
    public let arguments: [String]

    /// Creates a `simctl` command from a subcommand name and optional arguments.
    public init(_ subcommand: String, _ arguments: String...) {
        precondition(!subcommand.isEmpty, "A simctl command must include a subcommand.")
        self.arguments = [subcommand] + arguments
    }

    private init(arguments: [String]) {
        precondition(!arguments.isEmpty, "A simctl command must include at least one argument.")
        self.arguments = arguments
    }

    /// Creates a custom `simctl` command.
    public static func custom(_ subcommand: String, arguments: [String] = []) -> Self {
        Self(arguments: [subcommand] + arguments)
    }

    /// Builds a `help` command.
    public static func help(_ subject: String? = nil) -> Self {
        var arguments = ["help"]
        if let subject {
            arguments.append(subject)
        }
        return Self(arguments: arguments)
    }

    /// Builds a `list` command.
    public static func list(
        _ target: SimctlListTarget? = nil,
        json: Bool = false,
        searchTerm: String? = nil
    ) -> Self {
        var arguments = ["list"]
        if let target {
            arguments.append(contentsOf: target.arguments)
        }
        if let searchTerm {
            arguments.append(searchTerm)
        }
        if json {
            arguments.append("--json")
        }
        return Self(arguments: arguments)
    }

    /// Builds a `create` command.
    public static func create(name: String, deviceType: String, runtime: String) -> Self {
        Self(arguments: ["create", name, deviceType, runtime])
    }

    /// Builds a `clone` command.
    public static func clone(_ device: String, to name: String) -> Self {
        Self(arguments: ["clone", device, name])
    }

    /// Builds a `delete` command.
    public static func delete(_ devices: [String]) -> Self {
        Self(arguments: ["delete"] + devices)
    }

    /// Builds a `boot` command.
    public static func boot(_ device: String) -> Self {
        Self(arguments: ["boot", device])
    }

    /// Builds a `bootstatus` command.
    public static func bootStatus(_ device: String) -> Self {
        Self(arguments: ["bootstatus", device])
    }

    /// Builds a `shutdown` command.
    public static func shutdown(_ devices: [String]) -> Self {
        Self(arguments: ["shutdown"] + devices)
    }

    /// Builds an `erase` command.
    public static func erase(_ devices: [String]) -> Self {
        Self(arguments: ["erase"] + devices)
    }

    /// Builds a `rename` command.
    public static func rename(_ device: String, to name: String) -> Self {
        Self(arguments: ["rename", device, name])
    }

    /// Builds an `upgrade` command.
    public static func upgrade(_ devices: [String]) -> Self {
        Self(arguments: ["upgrade"] + devices)
    }

    /// Builds a `pair` command.
    public static func pair(_ watch: String, with phone: String) -> Self {
        Self(arguments: ["pair", watch, phone])
    }

    /// Builds an `unpair` command.
    public static func unpair(_ device: String) -> Self {
        Self(arguments: ["unpair", device])
    }

    /// Builds an `install` command.
    public static func install(_ device: String, appAt path: String) -> Self {
        Self(arguments: ["install", device, path])
    }

    /// Builds an `uninstall` command.
    public static func uninstall(_ device: String, bundleIdentifier: String) -> Self {
        Self(arguments: ["uninstall", device, bundleIdentifier])
    }

    /// Builds a `launch` command.
    public static func launch(_ device: String, bundleIdentifier: String) -> Self {
        Self(arguments: ["launch", device, bundleIdentifier])
    }

    /// Builds a `terminate` command.
    public static func terminate(_ device: String, bundleIdentifier: String) -> Self {
        Self(arguments: ["terminate", device, bundleIdentifier])
    }

    /// Builds a `spawn` command.
    public static func spawn(_ device: String, executable: String, arguments: [String] = []) -> Self {
        Self(arguments: ["spawn", device, executable] + arguments)
    }

    /// Builds an `openurl` command.
    public static func openURL(_ device: String, _ value: String) -> Self {
        Self(arguments: ["openurl", device, value])
    }

    /// Builds a `get_app_container` command.
    public static func getAppContainer(
        _ device: String,
        bundleIdentifier: String,
        container: String? = nil
    ) -> Self {
        var arguments = ["get_app_container", device, bundleIdentifier]
        if let container {
            arguments.append(container)
        }
        return Self(arguments: arguments)
    }

    /// Builds an `appinfo` command.
    public static func appInfo(_ device: String, bundleIdentifier: String) -> Self {
        Self(arguments: ["appinfo", device, bundleIdentifier])
    }

    /// Builds an `addmedia` command.
    public static func addMedia(_ device: String, files: [String]) -> Self {
        Self(arguments: ["addmedia", device] + files)
    }

    /// Builds a `pbcopy` command.
    public static func pbcopy(_ device: String) -> Self {
        Self(arguments: ["pbcopy", device])
    }

    /// Builds a `pbpaste` command.
    public static func pbpaste(_ device: String) -> Self {
        Self(arguments: ["pbpaste", device])
    }

    /// Builds an `io` command.
    public static func io(_ device: String, command: String, arguments: [String] = []) -> Self {
        Self(arguments: ["io", device, command] + arguments)
    }

    /// Builds a `privacy` command.
    public static func privacy(
        _ device: String,
        action: String,
        service: String,
        bundleIdentifier: String? = nil
    ) -> Self {
        var arguments = ["privacy", device, action, service]
        if let bundleIdentifier {
            arguments.append(bundleIdentifier)
        }
        return Self(arguments: arguments)
    }

    /// Builds a `status_bar` command.
    public static func statusBar(_ device: String, arguments: [String]) -> Self {
        Self(arguments: ["status_bar", device] + arguments)
    }

    /// Builds a `ui` command.
    public static func ui(_ device: String, arguments: [String]) -> Self {
        Self(arguments: ["ui", device] + arguments)
    }

    /// Builds a `push` command.
    public static func push(_ device: String, bundleIdentifier: String, payloadAt path: String) -> Self {
        Self(arguments: ["push", device, bundleIdentifier, path])
    }

    /// Builds a `notify_post` command.
    public static func notifyPost(_ device: String, notification: String) -> Self {
        Self(arguments: ["notify_post", device, notification])
    }

    /// Builds a `location` command.
    public static func location(_ device: String, action: String, arguments: [String] = []) -> Self {
        Self(arguments: ["location", device, action] + arguments)
    }

    /// Builds a `keychain` command.
    public static func keychain(_ device: String, arguments: [String]) -> Self {
        Self(arguments: ["keychain", device] + arguments)
    }

    /// Builds an `icloud_sync` command.
    public static func icloudSync(_ device: String) -> Self {
        Self(arguments: ["icloud_sync", device])
    }

    /// Builds a `runtime` command.
    public static func runtime(_ arguments: [String]) -> Self {
        Self(arguments: ["runtime"] + arguments)
    }

    /// Builds a `disk` command.
    public static func disk(_ arguments: [String]) -> Self {
        Self(arguments: ["disk"] + arguments)
    }

    /// Builds a `diagnose` command.
    public static func diagnose(arguments: [String] = []) -> Self {
        Self(arguments: ["diagnose"] + arguments)
    }
}
