#if Docker
import Foundation

/// The top-level Docker CLI command or command group to invoke.
public enum DockerSubcommand: String, Sendable, Equatable, Hashable {
    /// `docker builder` — manage builds.
    case builder
    /// `docker buildx` — use Docker Buildx and BuildKit workflows.
    case buildx
    /// `docker checkpoint` — manage checkpoints.
    case checkpoint
    /// `docker compose` — run Docker Compose commands.
    case compose
    /// `docker config` — manage Swarm configs.
    case config
    /// `docker container` — manage containers.
    case container
    /// `docker context` — manage Docker contexts.
    case context
    /// `docker debug` — debug containers or images with a toolbox shell.
    case debug
    /// `docker desktop` — manage Docker Desktop.
    case desktop
    /// `docker dhi` — manage Docker Hardened Images.
    case dhi
    /// `docker image` — manage images.
    case image
    /// `docker init` — create Docker starter files for a project.
    case initialize = "init"
    /// `docker inspect` — inspect Docker objects.
    case inspect
    /// `docker login` — authenticate to a registry.
    case login
    /// `docker logout` — log out from a registry.
    case logout
    /// `docker manifest` — manage image manifests.
    case manifest
    /// `docker mcp` — manage MCP servers and clients.
    case mcp
    /// `docker model` — use Docker Model Runner commands.
    case model
    /// `docker network` — manage networks.
    case network
    /// `docker node` — manage Swarm nodes.
    case node
    /// `docker offload` — control Docker Offload.
    case offload
    /// `docker pass` — manage local OS keychain secrets.
    case pass
    /// `docker plugin` — manage plugins.
    case plugin
    /// `docker sandbox` — use Docker Sandbox commands.
    case sandbox
    /// `docker scout` — use Docker Scout commands.
    case scout
    /// `docker search` — search Docker Hub.
    case search
    /// `docker secret` — manage Swarm secrets.
    case secret
    /// `docker service` — manage Swarm services.
    case service
    /// `docker stack` — manage Swarm stacks.
    case stack
    /// `docker swarm` — manage Swarm.
    case swarm
    /// `docker system` — manage Docker system resources.
    case system
    /// `docker trust` — manage image trust.
    case trust
    /// `docker version` — show Docker version information.
    case version
    /// `docker volume` — manage volumes.
    case volume
}

/// The progress output mode used by BuildKit-based build commands.
public enum DockerBuildProgress: String, Sendable, Equatable, Hashable {
    /// Automatically choose progress output based on the terminal.
    case auto
    /// Plain text progress suitable for CI logs.
    case plain
    /// TTY progress output.
    case tty
    /// Raw JSON progress output.
    case rawjson
}

/// A fluent wrapper for the Docker CLI (`docker`).
///
/// ``Docker`` focuses on automation-friendly Docker workflows: Buildx, Compose, container and
/// image management, Docker Debug, Docker MCP, Docker Scout, and project initialization. It models
/// common global flags and high-value command options while preserving raw escape hatches with
/// ``argument(_:)``, ``arguments(_:)``, and ``option(_:_:)``.
///
/// ```swift
/// let output = try await Docker(context: context)
///     .buildx("build")
///     .tag("owner/app:latest")
///     .file("Dockerfile")
///     .progress(.plain)
///     .positionalArgument(".")
///     .run()
/// ```
public struct Docker: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Docker CLI command family bound to a shell context.
    ///
    /// The default invocation is `docker version`, which is read-only but may still contact the
    /// configured daemon. Select daemon-free help output with ``argument(_:)`` if needed.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `docker` command's stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `docker` command's stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that selects a top-level Docker command or command group.
    public func subcommand(_ value: DockerSubcommand) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.nestedSubcommand = nil
        }
    }

    /// Returns a copy that selects a raw top-level Docker command or command group.
    public func subcommand(_ value: String) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.nestedSubcommand = nil
        }
    }

    /// Returns a copy that selects a top-level Docker command group and nested command.
    public func subcommand(_ value: DockerSubcommand, _ nested: String) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.nestedSubcommand = nested
        }
    }

    /// Returns a copy that selects a raw top-level Docker command group and nested command.
    public func subcommand(_ value: String, _ nested: String) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.nestedSubcommand = nested
        }
    }

    /// Returns a copy that configures a `docker buildx` command.
    public func buildx(_ nested: String? = nil) -> Self { commandGroup(.buildx, nested) }

    /// Returns a copy that configures a `docker compose` command.
    public func compose(_ nested: String? = nil) -> Self { commandGroup(.compose, nested) }

    /// Returns a copy that configures a `docker container` command.
    public func container(_ nested: String? = nil) -> Self { commandGroup(.container, nested) }

    /// Returns a copy that configures a `docker image` command.
    public func image(_ nested: String? = nil) -> Self { commandGroup(.image, nested) }

    /// Returns a copy that configures `docker init`.
    public func initialize() -> Self { commandGroup(.initialize, nil) }

    /// Returns a copy that configures a `docker debug` command for a target container or image.
    public func debug(_ target: String? = nil) -> Self {
        var result = commandGroup(.debug, nil)
        if let target { result = result.positionalArgument(target) }
        return result
    }

    /// Returns a copy that configures a `docker mcp` command.
    public func mcp(_ nested: String? = nil) -> Self { commandGroup(.mcp, nested) }

    /// Returns a copy that configures a `docker scout` command.
    public func scout(_ nested: String? = nil) -> Self { commandGroup(.scout, nested) }

    /// Returns a copy that configures a `docker system` command.
    public func system(_ nested: String? = nil) -> Self { commandGroup(.system, nested) }

    /// Returns a copy that configures a `docker version` command.
    public func version() -> Self { commandGroup(.version, nil) }

    /// Returns a copy that passes `--config <path>` before the Docker subcommand.
    public func configPath(_ path: String) -> Self { modified(self) { $0.state.configPath = path } }

    /// Returns a copy that passes `--context <name>` before the Docker subcommand.
    public func context(_ name: String) -> Self { modified(self) { $0.state.contextName = name } }

    /// Returns a copy that passes `--host <socket>` before the Docker subcommand.
    public func host(_ value: String) -> Self { modified(self) { $0.state.hostValue = value } }

    /// Returns a copy that passes `--log-level <level>` before the Docker subcommand.
    public func logLevel(_ value: String) -> Self { modified(self) { $0.state.logLevel = value } }

    /// Returns a copy that passes `--debug` before the Docker subcommand.
    public func debugMode(_ enabled: Bool = true) -> Self { modified(self) { $0.state.debugEnabled = enabled } }

    /// Returns a copy that passes `--tls` before the Docker subcommand.
    public func tls(_ enabled: Bool = true) -> Self { modified(self) { $0.state.tlsEnabled = enabled } }

    /// Returns a copy that passes `--tlsverify` before the Docker subcommand.
    public func tlsVerify(_ enabled: Bool = true) -> Self { modified(self) { $0.state.tlsVerifyEnabled = enabled } }

    /// Returns a copy that passes `--platform <platform>`.
    public func platform(_ value: String) -> Self { modified(self) { $0.state.platformValue = value } }

    /// Returns a copy that passes `--file <path>`.
    public func file(_ path: String) -> Self { modified(self) { $0.state.filePath = path } }

    /// Returns a copy that passes `--tag <name>`.
    public func tag(_ name: String) -> Self { modified(self) { $0.state.tags += [name] } }

    /// Returns a copy that passes multiple `--tag` values.
    public func tags(_ names: [String]) -> Self { modified(self) { $0.state.tags += names } }

    /// Returns a copy that passes `--build-arg <name=value>`.
    public func buildArg(_ value: String) -> Self { modified(self) { $0.state.buildArgs += [value] } }

    /// Returns a copy that passes multiple `--build-arg` values.
    public func buildArgs(_ values: [String]) -> Self { modified(self) { $0.state.buildArgs += values } }

    /// Returns a copy that passes `--progress <mode>`.
    public func progress(_ value: DockerBuildProgress) -> Self { modified(self) { $0.state.progressMode = value } }

    /// Returns a copy that passes `--push`.
    public func push(_ enabled: Bool = true) -> Self { modified(self) { $0.state.pushes = enabled } }

    /// Returns a copy that passes `--load`.
    public func load(_ enabled: Bool = true) -> Self { modified(self) { $0.state.loads = enabled } }

    /// Returns a copy that passes `--pull`.
    public func pull(_ enabled: Bool = true) -> Self { modified(self) { $0.state.pulls = enabled } }

    /// Returns a copy that passes `--name <name>`.
    public func name(_ value: String) -> Self { modified(self) { $0.state.nameValue = value } }

    /// Returns a copy that passes `--rm`.
    public func removeWhenDone(_ enabled: Bool = true) -> Self { modified(self) { $0.state.removesWhenDone = enabled } }

    /// Returns a copy that passes `--detach`.
    public func detach(_ enabled: Bool = true) -> Self { modified(self) { $0.state.detaches = enabled } }

    /// Returns a copy that passes `--interactive`.
    public func interactive(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isInteractive = enabled } }

    /// Returns a copy that passes `--tty`.
    public func tty(_ enabled: Bool = true) -> Self { modified(self) { $0.state.allocatesTTY = enabled } }

    /// Returns a copy that passes `--command <command>` for commands like `docker debug`.
    public func commandString(_ value: String) -> Self { modified(self) { $0.state.commandValue = value } }

    /// Returns a copy that passes `--shell <shell>` for `docker debug`.
    public func shell(_ value: String) -> Self { modified(self) { $0.state.shellValue = value } }

    /// Returns a copy that passes `--format <template>`.
    public func format(_ value: String) -> Self { modified(self) { $0.state.formatValue = value } }

    /// Returns a copy that appends a raw option before positional arguments.
    public func option(_ name: String) -> Self { modified(self) { $0.state.extraArguments += [name] } }

    /// Returns a copy that appends a raw option and value before positional arguments.
    public func option(_ name: String, _ value: String) -> Self {
        modified(self) { $0.state.extraArguments += [name, value] }
    }

    /// Returns a copy that appends a raw argument before positional arguments.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw arguments before positional arguments.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends a positional argument after modeled and raw options.
    public func positionalArgument(_ value: String) -> Self {
        modified(self) { $0.state.positionalArguments += [value] }
    }

    /// Returns a copy that appends positional arguments after modeled and raw options.
    public func positionalArguments(_ values: [String]) -> Self {
        modified(self) { $0.state.positionalArguments += values }
    }

    /// Builds the raw `docker` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []

        if let configPath = state.configPath {
            arguments.append("--config")
            arguments.append(configPath)
        }

        if let contextName = state.contextName {
            arguments.append("--context")
            arguments.append(contextName)
        }

        if let hostValue = state.hostValue {
            arguments.append("--host")
            arguments.append(hostValue)
        }

        if let logLevel = state.logLevel {
            arguments.append("--log-level")
            arguments.append(logLevel)
        }

        if state.debugEnabled { arguments.append("--debug") }
        if state.tlsEnabled { arguments.append("--tls") }
        if state.tlsVerifyEnabled { arguments.append("--tlsverify") }

        if let subcommand = state.subcommand {
            arguments.append(subcommand)
        }

        if let nestedSubcommand = state.nestedSubcommand {
            arguments.append(nestedSubcommand)
        }

        if let platformValue = state.platformValue {
            arguments.append("--platform")
            arguments.append(platformValue)
        }

        if let filePath = state.filePath {
            arguments.append("--file")
            arguments.append(filePath)
        }

        for tag in state.tags {
            arguments.append("--tag")
            arguments.append(tag)
        }

        for buildArg in state.buildArgs {
            arguments.append("--build-arg")
            arguments.append(buildArg)
        }

        if let progressMode = state.progressMode {
            arguments.append("--progress")
            arguments.append(progressMode.rawValue)
        }

        if state.pushes { arguments.append("--push") }
        if state.loads { arguments.append("--load") }
        if state.pulls { arguments.append("--pull") }

        if let nameValue = state.nameValue {
            arguments.append("--name")
            arguments.append(nameValue)
        }

        if state.removesWhenDone { arguments.append("--rm") }
        if state.detaches { arguments.append("--detach") }
        if state.isInteractive { arguments.append("--interactive") }
        if state.allocatesTTY { arguments.append("--tty") }

        if let commandValue = state.commandValue {
            arguments.append("--command")
            arguments.append(commandValue)
        }

        if let shellValue = state.shellValue {
            arguments.append("--shell")
            arguments.append(shellValue)
        }

        if let formatValue = state.formatValue {
            arguments.append("--format")
            arguments.append(formatValue)
        }

        arguments.append(contentsOf: state.extraArguments)
        arguments.append(contentsOf: state.positionalArguments)

        let base = Command("docker")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func commandGroup(_ value: DockerSubcommand, _ nested: String?) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.nestedSubcommand = nested
        }
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var subcommand: String? = DockerSubcommand.version.rawValue
    var nestedSubcommand: String? = nil
    var configPath: String? = nil
    var contextName: String? = nil
    var hostValue: String? = nil
    var logLevel: String? = nil
    var debugEnabled: Bool = false
    var tlsEnabled: Bool = false
    var tlsVerifyEnabled: Bool = false
    var platformValue: String? = nil
    var filePath: String? = nil
    var tags: [String] = []
    var buildArgs: [String] = []
    var progressMode: DockerBuildProgress? = nil
    var pushes: Bool = false
    var loads: Bool = false
    var pulls: Bool = false
    var nameValue: String? = nil
    var removesWhenDone: Bool = false
    var detaches: Bool = false
    var isInteractive: Bool = false
    var allocatesTTY: Bool = false
    var commandValue: String? = nil
    var shellValue: String? = nil
    var formatValue: String? = nil
    var extraArguments: [String] = []
    var positionalArguments: [String] = []
}
#endif
