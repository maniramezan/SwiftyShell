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
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a kubectl command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that selects a kubectl subcommand.
    public func subcommand(_ value: KubectlSubcommand) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.resources = []
        }
    }

    /// Returns a copy that selects a raw kubectl subcommand.
    public func subcommand(_ value: String) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.resources = []
        }
    }

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
        modified(self) {
            $0.state.subcommand = KubectlSubcommand.exec.rawValue
            $0.state.resources = [resource]
            $0.state.remoteCommand = command
        }
    }

    /// Returns a copy that passes `--kubeconfig <path>`.
    public func kubeconfig(_ path: String) -> Self { modified(self) { $0.state.kubeconfigPath = path } }

    /// Returns a copy that passes `--context <name>`.
    ///
    /// The method is named `contextName` to avoid colliding with the ``ShellContext``-backed
    /// ``context`` property shared by command families.
    public func contextName(_ name: String) -> Self { modified(self) { $0.state.kubeContextName = name } }

    /// Returns a copy that passes `--namespace <name>`.
    public func namespace(_ name: String) -> Self { modified(self) { $0.state.namespaceName = name } }

    /// Returns a copy that passes `--output <format>`.
    public func output(_ format: String) -> Self { modified(self) { $0.state.outputFormat = format } }

    /// Returns a copy that passes `--filename <path>`.
    public func filename(_ path: String) -> Self { modified(self) { $0.state.filenames += [path] } }

    /// Returns a copy that passes `--selector <selector>`.
    public func selector(_ value: String) -> Self { modified(self) { $0.state.selectorValue = value } }

    /// Returns a copy that passes `--container <name>`.
    public func container(_ name: String) -> Self { modified(self) { $0.state.containerName = name } }

    /// Returns a copy that passes `--all-namespaces`.
    public func allNamespaces(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.allNamespacesEnabled = enabled }
    }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends a resource or command argument.
    public func positionalArgument(_ value: String) -> Self { modified(self) { $0.state.resources += [value] } }

    /// Returns a copy that appends resources or command arguments.
    public func positionalArguments(_ values: [String]) -> Self { modified(self) { $0.state.resources += values } }

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
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var subcommand: String = KubectlSubcommand.version.rawValue
    var kubeconfigPath: String? = nil
    var kubeContextName: String? = nil
    var namespaceName: String? = nil
    var outputFormat: String? = nil
    var filenames: [String] = []
    var selectorValue: String? = nil
    var containerName: String? = nil
    var allNamespacesEnabled: Bool = false
    var extraArguments: [String] = []
    var resources: [String] = []
    var remoteCommand: [String] = []
}
#endif
