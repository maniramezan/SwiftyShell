#if Kubectl
import Foundation

/// The top-level kubectl command to invoke.
public enum KubectlSubcommand: String, Sendable, Equatable, Hashable {
    /// `kubectl get` — display resources.
    case get
    /// `kubectl describe` — show detailed resource information.
    case describe
    /// `kubectl apply` — apply a configuration.
    case apply
    /// `kubectl delete` — delete resources.
    case delete
    /// `kubectl logs` — print pod logs.
    case logs
    /// `kubectl exec` — execute a command in a container.
    case exec
    /// `kubectl rollout` — manage rollouts.
    case rollout
    /// `kubectl config` — manage kubeconfig.
    case config
    /// `kubectl version` — print client/server version information.
    case version
}

/// A fluent wrapper for the Kubernetes `kubectl` CLI.
///
/// ``Kubectl`` covers common automation commands and shared selection flags
/// such as namespace, context, output format, labels, files, and containers.
///
/// ```swift
/// let pods = try await Kubectl()
///     .get("pods")
///     .namespace("default")
///     .output("json")
///     .run()
/// ```
public struct Kubectl: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a kubectl command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects a kubectl subcommand.
    public func subcommand(_ value: KubectlSubcommand) -> Self { copy(subcommand: value.rawValue, resources: []) }

    /// Returns a copy that selects a raw kubectl subcommand.
    public func subcommand(_ value: String) -> Self { copy(subcommand: value, resources: []) }

    /// Returns a copy configured for `kubectl get <resource>`.
    public func get(_ resource: String? = nil) -> Self { resourceCommand(.get, resource) }

    /// Returns a copy configured for `kubectl describe <resource>`.
    public func describe(_ resource: String? = nil) -> Self { resourceCommand(.describe, resource) }

    /// Returns a copy configured for `kubectl apply`.
    public func apply() -> Self { subcommand(.apply) }

    /// Returns a copy configured for `kubectl delete <resource>`.
    public func delete(_ resource: String? = nil) -> Self { resourceCommand(.delete, resource) }

    /// Returns a copy configured for `kubectl logs <resource>`.
    public func logs(_ resource: String? = nil) -> Self { resourceCommand(.logs, resource) }

    /// Returns a copy configured for `kubectl exec <resource> -- <command>`.
    ///
    /// The separator is inserted automatically after kubectl options and the resource, ensuring
    /// command flags are forwarded to the container rather than parsed by kubectl.
    ///
    /// - Parameters:
    ///   - resource: The pod or resource containing the target container.
    ///   - command: The executable and arguments to run in the container.
    public func exec(_ resource: String, command: [String]) -> Self {
        copy(subcommand: KubectlSubcommand.exec.rawValue, resources: [resource], remoteCommand: command)
    }

    /// Returns a copy that passes `--kubeconfig <path>`.
    public func kubeconfig(_ path: String) -> Self { copy(kubeconfigPath: path) }

    /// Returns a copy that passes `--context <name>`.
    ///
    /// The method is named `contextName` to avoid colliding with the ``ShellContext``-backed
    /// ``context`` property shared by command families.
    public func contextName(_ name: String) -> Self { copy(kubeContextName: name) }

    /// Returns a copy that passes `--namespace <name>`.
    public func namespace(_ name: String) -> Self { copy(namespaceName: name) }

    /// Returns a copy that passes `--output <format>`.
    public func output(_ format: String) -> Self { copy(outputFormat: format) }

    /// Returns a copy that passes `--filename <path>`.
    public func filename(_ path: String) -> Self { copy(filenames: state.filenames + [path]) }

    /// Returns a copy that passes `--selector <selector>`.
    public func selector(_ value: String) -> Self { copy(selectorValue: value) }

    /// Returns a copy that passes `--container <name>`.
    public func container(_ name: String) -> Self { copy(containerName: name) }

    /// Returns a copy that passes `--all-namespaces`.
    public func allNamespaces(_ enabled: Bool = true) -> Self { copy(allNamespacesEnabled: enabled) }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a resource or command argument.
    public func positionalArgument(_ value: String) -> Self { copy(resources: state.resources + [value]) }

    /// Returns a copy that appends resources or command arguments.
    public func positionalArguments(_ values: [String]) -> Self { copy(resources: state.resources + values) }

    /// Builds the raw `kubectl` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        appendOption("--kubeconfig", state.kubeconfigPath, to: &arguments)
        appendOption("--context", state.kubeContextName, to: &arguments)
        arguments.append(state.subcommand)
        appendOption("--namespace", state.namespaceName, to: &arguments)
        appendOption("--output", state.outputFormat, to: &arguments)
        for filename in state.filenames { arguments += ["--filename", filename] }
        appendOption("--selector", state.selectorValue, to: &arguments)
        appendOption("--container", state.containerName, to: &arguments)
        if state.allNamespacesEnabled { arguments.append("--all-namespaces") }
        arguments += state.extraArguments + state.resources
        if state.subcommand == KubectlSubcommand.exec.rawValue, !state.remoteCommand.isEmpty {
            arguments.append("--")
            arguments += state.remoteCommand
        }
        let base = Command("kubectl").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func resourceCommand(_ subcommand: KubectlSubcommand, _ resource: String?) -> Self {
        var result = self.subcommand(subcommand)
        if let resource { result = result.positionalArgument(resource) }
        return result
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: String? = nil,
        kubeconfigPath: String?? = nil,
        kubeContextName: String?? = nil,
        namespaceName: String?? = nil,
        outputFormat: String?? = nil,
        filenames: [String]? = nil,
        selectorValue: String?? = nil,
        containerName: String?? = nil,
        allNamespacesEnabled: Bool? = nil,
        extraArguments: [String]? = nil,
        resources: [String]? = nil,
        remoteCommand: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                kubeconfigPath: kubeconfigPath ?? state.kubeconfigPath,
                kubeContextName: kubeContextName ?? state.kubeContextName,
                namespaceName: namespaceName ?? state.namespaceName,
                outputFormat: outputFormat ?? state.outputFormat,
                filenames: filenames ?? state.filenames,
                selectorValue: selectorValue ?? state.selectorValue,
                containerName: containerName ?? state.containerName,
                allNamespacesEnabled: allNamespacesEnabled ?? state.allNamespacesEnabled,
                extraArguments: extraArguments ?? state.extraArguments,
                resources: resources ?? state.resources,
                remoteCommand: remoteCommand ?? state.remoteCommand
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let subcommand: String
    let kubeconfigPath: String?
    let kubeContextName: String?
    let namespaceName: String?
    let outputFormat: String?
    let filenames: [String]
    let selectorValue: String?
    let containerName: String?
    let allNamespacesEnabled: Bool
    let extraArguments: [String]
    let resources: [String]
    let remoteCommand: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: String = KubectlSubcommand.version.rawValue,
        kubeconfigPath: String? = nil,
        kubeContextName: String? = nil,
        namespaceName: String? = nil,
        outputFormat: String? = nil,
        filenames: [String] = [],
        selectorValue: String? = nil,
        containerName: String? = nil,
        allNamespacesEnabled: Bool = false,
        extraArguments: [String] = [],
        resources: [String] = [],
        remoteCommand: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.kubeconfigPath = kubeconfigPath
        self.kubeContextName = kubeContextName
        self.namespaceName = namespaceName
        self.outputFormat = outputFormat
        self.filenames = filenames
        self.selectorValue = selectorValue
        self.containerName = containerName
        self.allNamespacesEnabled = allNamespacesEnabled
        self.extraArguments = extraArguments
        self.resources = resources
        self.remoteCommand = remoteCommand
    }
}
#endif
