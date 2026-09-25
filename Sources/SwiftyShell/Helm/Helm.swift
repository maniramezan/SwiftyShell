#if Helm
import Foundation

/// An output format supported by Helm release operations.
public enum HelmOutputFormat: String, Sendable, Equatable, Hashable {
    /// Human-readable tabular output.
    case table
    /// JSON output.
    case json
    /// YAML output.
    case yaml
}

/// A Helm dry-run execution mode.
public enum HelmDryRunMode: String, Sendable, Equatable, Hashable {
    /// Render locally without connecting to a Kubernetes cluster.
    case client
    /// Render and validate against the Kubernetes cluster.
    case server
}

/// A release state accepted by ``HelmList/status(_:)``.
public enum HelmReleaseStatus: String, Sendable, Equatable, Hashable {
    /// Releases deployed successfully.
    case deployed
    /// Releases whose deployment failed.
    case failed
    /// Releases with an operation still pending.
    case pending
    /// Releases retained after uninstallation.
    case uninstalled
    /// Releases superseded by a newer revision.
    case superseded
    /// Releases currently being uninstalled.
    case uninstalling
}

/// A configured entry point for operation-specific Helm commands.
///
/// Configure cluster selection once, then create an operation whose API exposes only flags valid
/// for that Helm grammar.
///
/// ```swift
/// let command = Helm()
///     .namespace("production")
///     .kubeContext("prod-cluster")
///     .upgrade(release: "api", chart: "./charts/api")
///     .installIfMissing()
///     .valuesFile("values.production.yaml")
///     .set("image.tag", to: "1.4.0")
/// ```
public struct Helm: ToolConfigurableCommandFamily {
    private var settings: HelmSettings

    /// The shell context used when running Helm operations.
    public var context: ShellContext { settings.config.context }

    /// Creates a Helm command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.settings = HelmSettings(config: ToolConfiguration(context: context))
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) {
            $0.settings.config = update(settings.config)
        }
    }

    /// Returns a copy that scopes subsequent operations to a Kubernetes namespace.
    public func namespace(_ name: String) -> Self {
        modified(self) {
            $0.settings.namespace = name
        }
    }

    /// Returns a copy that uses a named kubeconfig context.
    public func kubeContext(_ name: String) -> Self {
        modified(self) {
            $0.settings.kubeContext = name
        }
    }

    /// Returns a copy that uses a specific kubeconfig file.
    public func kubeconfig(_ path: String) -> Self {
        modified(self) {
            $0.settings.kubeconfig = path
        }
    }

    /// Creates a local chart-rendering operation.
    public func template(name: String? = nil, chart: String) -> HelmTemplate {
        HelmTemplate(settings: settings, name: name, chart: chart)
    }

    /// Creates a chart linting operation.
    public func lint(chart: String) -> HelmLint {
        HelmLint(settings: settings, chart: chart)
    }

    /// Creates a chart installation operation.
    public func install(release: String, chart: String) -> HelmInstall {
        HelmInstall(settings: settings, release: release, chart: chart)
    }

    /// Creates a release upgrade operation.
    public func upgrade(release: String, chart: String) -> HelmUpgrade {
        HelmUpgrade(settings: settings, release: release, chart: chart)
    }

    /// Creates an operation that uninstalls one or more releases.
    public func uninstall(_ releases: String...) -> HelmUninstall {
        HelmUninstall(settings: settings, releases: releases)
    }

    /// Creates an operation that lists releases.
    public func list() -> HelmList {
        HelmList(settings: settings)
    }

    /// Creates an operation that displays a release's status.
    public func status(release: String) -> HelmStatus {
        HelmStatus(settings: settings, release: release)
    }
}

/// A `helm template` operation.
///
/// Use this operation to render a chart locally with ordered values overrides.
///
/// ```swift
/// let output = try await Helm().template(name: "api", chart: "./chart")
///     .valuesFile("values.yaml")
///     .showOnly("templates/deployment.yaml")
///     .run()
/// ```
public struct HelmTemplate: RunnableCommandFamily {
    private var state: HelmValueOperationState
    private var name: String?
    private var chart: String
    private var outputDirectory: String?
    private var shownTemplates: [String]
    private var includeCRDsEnabled: Bool

    fileprivate init(settings: HelmSettings, name: String?, chart: String) {
        self.state = HelmValueOperationState(settings: settings)
        self.name = name
        self.chart = chart
        self.outputDirectory = nil
        self.shownTemplates = []
        self.includeCRDsEnabled = false
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state.operation.settings.config = update(state.settings.config)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.operation.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.operation.stderr = destination
        }
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", path)
        }
    }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", paths)
        }
    }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-string", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-file", "\(key)=\(path)")
        }
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-json", "\(key)=\(value)")
        }
    }

    /// Returns a copy that writes rendered files below a directory instead of stdout.
    public func outputDirectory(_ path: String) -> Self {
        modified(self) { copy in
            copy.outputDirectory = path
        }
    }

    /// Returns a copy that renders only a specific chart template.
    public func showOnly(_ path: String) -> Self {
        modified(self) { copy in
            copy.shownTemplates = shownTemplates + [path]
        }
    }

    /// Returns a copy that includes custom resource definitions in rendered output.
    public func includeCRDs(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.includeCRDsEnabled = enabled
        }
    }

    /// Builds the raw `helm template` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "template")
        appendOption("--output-dir", outputDirectory, to: &arguments)
        for path in shownTemplates { arguments += ["--show-only", path] }
        if includeCRDsEnabled { arguments.append("--include-crds") }
        if let name { arguments.append(name) }
        arguments.append(chart)
        return state.command(arguments)
    }

}

/// A `helm lint` operation.
///
/// ```swift
/// try await Helm().lint(chart: "./chart").strict().withSubcharts().run()
/// ```
public struct HelmLint: RunnableCommandFamily {
    private var state: HelmValueOperationState
    private var chart: String
    private var strictEnabled: Bool
    private var quietEnabled: Bool
    private var withSubchartsEnabled: Bool
    private var kubeVersionValue: String?

    fileprivate init(settings: HelmSettings, chart: String) {
        self.state = HelmValueOperationState(settings: settings)
        self.chart = chart
        self.strictEnabled = false
        self.quietEnabled = false
        self.withSubchartsEnabled = false
        self.kubeVersionValue = nil
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state.operation.settings.config = update(state.settings.config)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.operation.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.operation.stderr = destination
        }
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", path)
        }
    }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", paths)
        }
    }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-string", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-file", "\(key)=\(path)")
        }
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-json", "\(key)=\(value)")
        }
    }

    /// Returns a copy that fails when lint warnings are emitted.
    public func strict(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.strictEnabled = enabled
        }
    }

    /// Returns a copy that prints only warnings and errors.
    public func quiet(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.quietEnabled = enabled
        }
    }

    /// Returns a copy that also lints dependent charts.
    public func withSubcharts(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.withSubchartsEnabled = enabled
        }
    }

    /// Returns a copy that checks capabilities and deprecations for a Kubernetes version.
    public func kubeVersion(_ version: String) -> Self {
        modified(self) { copy in
            copy.kubeVersionValue = version
        }
    }

    /// Builds the raw `helm lint` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "lint")
        if strictEnabled { arguments.append("--strict") }
        if quietEnabled { arguments.append("--quiet") }
        if withSubchartsEnabled { arguments.append("--with-subcharts") }
        appendOption("--kube-version", kubeVersionValue, to: &arguments)
        arguments.append(chart)
        return state.command(arguments)
    }

}

/// A `helm install` operation.
///
/// ```swift
/// try await Helm().namespace("production")
///     .install(release: "api", chart: "./chart")
///     .createNamespace()
///     .valuesFile("values.yaml")
///     .run()
/// ```
public struct HelmInstall: RunnableCommandFamily {
    private var state: HelmDeploymentState
    private var release: String
    private var chart: String

    fileprivate init(settings: HelmSettings, release: String, chart: String) {
        self.state = HelmDeploymentState(settings: settings)
        self.release = release
        self.chart = chart
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.values.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state = state.updatingConfiguration(update)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.values.operation.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.values.operation.stderr = destination
        }
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", path)
        }
    }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", paths)
        }
    }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-string", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-file", "\(key)=\(path)")
        }
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-json", "\(key)=\(value)")
        }
    }

    /// Returns a copy that creates the release namespace when it is absent.
    public func createNamespace(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.state.createNamespace = enabled
        }
    }

    /// Returns a copy that performs a dry run in the selected mode.
    public func dryRun(_ mode: HelmDryRunMode) -> Self {
        modified(self) { copy in
            copy.state.dryRun = mode
        }
    }

    /// Returns a copy that waits for resources to become ready.
    public func wait(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.state.wait = enabled
        }
    }

    /// Returns a copy that selects a chart version or version constraint.
    public func version(_ value: String) -> Self {
        modified(self) { copy in
            copy.state.version = value
        }
    }

    /// Returns a copy that selects the command's structured output format.
    public func output(_ format: HelmOutputFormat) -> Self {
        modified(self) { copy in
            copy.state.output = format
        }
    }

    /// Builds the raw `helm install` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "install")
        arguments += [release, chart]
        return state.values.command(arguments)
    }

}

/// A `helm upgrade` operation with optional install behavior.
///
/// ```swift
/// try await Helm().upgrade(release: "api", chart: "./chart")
///     .installIfMissing()
///     .reuseValues()
///     .set("image.tag", to: "1.4.0")
///     .run()
/// ```
public struct HelmUpgrade: RunnableCommandFamily {
    private var state: HelmDeploymentState
    private var release: String
    private var chart: String
    private var installIfMissingEnabled: Bool
    private enum ValuesMode: Sendable { case reuse, reset }
    private var valuesMode: ValuesMode?
    private var cleanupOnFailureEnabled: Bool

    fileprivate init(settings: HelmSettings, release: String, chart: String) {
        self.state = HelmDeploymentState(settings: settings)
        self.release = release
        self.chart = chart
        self.installIfMissingEnabled = false
        self.valuesMode = nil
        self.cleanupOnFailureEnabled = false
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.values.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state = state.updatingConfiguration(update)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.values.operation.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.values.operation.stderr = destination
        }
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", path)
        }
    }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--values", paths)
        }
    }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-string", "\(key)=\(value)")
        }
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-file", "\(key)=\(path)")
        }
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        modified(self) { copy in
            copy.state = state.appending("--set-json", "\(key)=\(value)")
        }
    }

    /// Returns a copy that installs the chart when the release does not exist.
    public func installIfMissing(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.installIfMissingEnabled = enabled
        }
    }

    /// Returns a copy that creates the namespace when installation is needed.
    public func createNamespace(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.state.createNamespace = enabled
        }
    }

    /// Returns a copy that merges the previous release values into new overrides.
    ///
    /// Mutually exclusive with ``resetValues(_:)``; the last one enabled wins.
    public func reuseValues(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.valuesMode = toggledMode(valuesMode, .reuse, enabled: enabled)
        }
    }

    /// Returns a copy that resets values to those built into the chart.
    ///
    /// Mutually exclusive with ``reuseValues(_:)``; the last one enabled wins.
    public func resetValues(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.valuesMode = toggledMode(valuesMode, .reset, enabled: enabled)
        }
    }

    /// Returns a copy that removes newly created resources when the upgrade fails.
    public func cleanupOnFailure(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.cleanupOnFailureEnabled = enabled
        }
    }

    /// Returns a copy that performs a dry run in the selected mode.
    public func dryRun(_ mode: HelmDryRunMode) -> Self {
        modified(self) { copy in
            copy.state.dryRun = mode
        }
    }

    /// Returns a copy that waits for resources to become ready.
    public func wait(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.state.wait = enabled
        }
    }

    /// Returns a copy that selects a chart version or version constraint.
    public func version(_ value: String) -> Self {
        modified(self) { copy in
            copy.state.version = value
        }
    }

    /// Returns a copy that selects the command's structured output format.
    public func output(_ format: HelmOutputFormat) -> Self {
        modified(self) { copy in
            copy.state.output = format
        }
    }

    /// Builds the raw `helm upgrade` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "upgrade")
        if installIfMissingEnabled { arguments.append("--install") }
        if valuesMode == .reuse { arguments.append("--reuse-values") }
        if valuesMode == .reset { arguments.append("--reset-values") }
        if cleanupOnFailureEnabled { arguments.append("--cleanup-on-fail") }
        arguments += [release, chart]
        return state.values.command(arguments)
    }

}

/// A `helm uninstall` operation.
///
/// ```swift
/// try await Helm().namespace("staging").uninstall("api", "worker").wait().run()
/// ```
public struct HelmUninstall: RunnableCommandFamily {
    private var state: HelmOperationState
    private var releases: [String]
    private var dryRunEnabled: Bool
    private var keepHistoryEnabled: Bool
    private var ignoreNotFoundEnabled: Bool
    private var waitEnabled: Bool

    fileprivate init(settings: HelmSettings, releases: [String]) {
        self.state = HelmOperationState(settings: settings)
        self.releases = releases
        self.dryRunEnabled = false
        self.keepHistoryEnabled = false
        self.ignoreNotFoundEnabled = false
        self.waitEnabled = false
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state.settings.config = update(state.settings.config)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.stderr = destination
        }
    }

    /// Returns a copy that simulates uninstallation.
    public func dryRun(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.dryRunEnabled = enabled
        }
    }

    /// Returns a copy that retains release history after removing resources.
    public func keepHistory(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.keepHistoryEnabled = enabled
        }
    }

    /// Returns a copy that treats missing releases as successfully uninstalled.
    public func ignoreNotFound(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.ignoreNotFoundEnabled = enabled
        }
    }

    /// Returns a copy that waits for resources to be removed.
    public func wait(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.waitEnabled = enabled
        }
    }

    /// Builds the raw `helm uninstall` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "uninstall")
        if dryRunEnabled { arguments.append("--dry-run") }
        if keepHistoryEnabled { arguments.append("--keep-history") }
        if ignoreNotFoundEnabled { arguments.append("--ignore-not-found") }
        if waitEnabled { arguments.append("--wait") }
        arguments += releases
        return state.command(arguments)
    }

}

/// A `helm list` operation.
///
/// ```swift
/// let output = try await Helm().list().allNamespaces().status(.deployed).output(.json).run()
/// ```
public struct HelmList: RunnableCommandFamily {
    private var state: HelmOperationState
    private var allNamespacesEnabled: Bool
    private var statuses: [HelmReleaseStatus]
    private var outputFormat: HelmOutputFormat?
    private var filterValue: String?
    private var maximum: Int?
    private var offsetValue: Int?

    fileprivate init(settings: HelmSettings) {
        self.state = HelmOperationState(settings: settings)
        self.allNamespacesEnabled = false
        self.statuses = []
        self.outputFormat = nil
        self.filterValue = nil
        self.maximum = nil
        self.offsetValue = nil
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state.settings.config = update(state.settings.config)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.stderr = destination
        }
    }

    /// Returns a copy that lists releases across every namespace.
    public func allNamespaces(_ enabled: Bool = true) -> Self {
        modified(self) { copy in
            copy.allNamespacesEnabled = enabled
        }
    }

    /// Returns a copy that includes releases with the selected state.
    public func status(_ value: HelmReleaseStatus) -> Self {
        modified(self) { copy in
            copy.statuses = statuses + [value]
        }
    }

    /// Returns a copy that selects the command's output format.
    public func output(_ format: HelmOutputFormat) -> Self {
        modified(self) { copy in
            copy.outputFormat = format
        }
    }

    /// Returns a copy that filters release names with a Perl-compatible regular expression.
    public func filter(_ expression: String) -> Self {
        modified(self) { copy in
            copy.filterValue = expression
        }
    }

    /// Returns a copy that limits the number of fetched releases.
    public func max(_ count: Int) -> Self {
        modified(self) { copy in
            copy.maximum = count
        }
    }

    /// Returns a copy that starts listing at a release index.
    public func offset(_ index: Int) -> Self {
        modified(self) { copy in
            copy.offsetValue = index
        }
    }

    /// Builds the raw `helm list` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "list")
        if allNamespacesEnabled { arguments.append("--all-namespaces") }
        for status in statuses { arguments.append("--\(status.rawValue)") }
        appendOption("--output", outputFormat?.rawValue, to: &arguments)
        appendOption("--filter", filterValue, to: &arguments)
        if let maximum { arguments += ["--max", String(maximum)] }
        if let offsetValue { arguments += ["--offset", String(offsetValue)] }
        return state.command(arguments)
    }

}

/// A `helm status` operation.
///
/// ```swift
/// let output = try await Helm().status(release: "api").revision(3).output(.yaml).run()
/// ```
public struct HelmStatus: RunnableCommandFamily {
    private var state: HelmOperationState
    private var release: String
    private var outputFormat: HelmOutputFormat?
    private var revisionValue: Int?

    fileprivate init(settings: HelmSettings, release: String) {
        self.state = HelmOperationState(settings: settings)
        self.release = release
        self.outputFormat = nil
        self.revisionValue = nil
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { copy in
            copy.state.settings.config = update(state.settings.config)
        }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.stdout = destination
        }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { copy in
            copy.state.stderr = destination
        }
    }

    /// Returns a copy that selects the command's output format.
    public func output(_ format: HelmOutputFormat) -> Self {
        modified(self) { copy in
            copy.outputFormat = format
        }
    }

    /// Returns a copy that displays a specific release revision.
    public func revision(_ value: Int) -> Self {
        modified(self) { copy in
            copy.revisionValue = value
        }
    }

    /// Builds the raw `helm status` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "status")
        appendOption("--output", outputFormat?.rawValue, to: &arguments)
        if let revisionValue { arguments += ["--revision", String(revisionValue)] }
        arguments.append(release)
        return state.command(arguments)
    }

}

private struct HelmSettings: Sendable {
    var config: ToolConfiguration
    var namespace: String?
    var kubeContext: String?
    var kubeconfig: String?

    init(
        config: ToolConfiguration,
        namespace: String? = nil,
        kubeContext: String? = nil,
        kubeconfig: String? = nil
    ) {
        self.config = config
        self.namespace = namespace
        self.kubeContext = kubeContext
        self.kubeconfig = kubeconfig
    }

}

private struct HelmOperationState: Sendable {
    var settings: HelmSettings
    var stdout: OutputDestination
    var stderr: OutputDestination

    init(settings: HelmSettings, stdout: OutputDestination = .capture, stderr: OutputDestination = .capture) {
        self.settings = settings
        self.stdout = stdout
        self.stderr = stderr
    }

    func arguments(command: String) -> [String] {
        var arguments = [command]
        appendOption("--namespace", settings.namespace, to: &arguments)
        appendOption("--kube-context", settings.kubeContext, to: &arguments)
        appendOption("--kubeconfig", settings.kubeconfig, to: &arguments)
        return arguments
    }

    func command(_ arguments: [String]) -> Command {
        settings.config.apply(to: Command("helm").args(arguments).stdout(stdout).stderr(stderr))
    }

}

private struct HelmValueOperationState: Sendable {
    var operation: HelmOperationState
    var valueArguments: [String]

    var settings: HelmSettings { operation.settings }

    init(settings: HelmSettings, valueArguments: [String] = []) {
        self.operation = HelmOperationState(settings: settings)
        self.valueArguments = valueArguments
    }

    private init(operation: HelmOperationState, valueArguments: [String]) {
        self.operation = operation
        self.valueArguments = valueArguments
    }

    func arguments(command: String) -> [String] { operation.arguments(command: command) + valueArguments }

    func command(_ arguments: [String]) -> Command { operation.command(arguments) }

    func appending(_ flag: String, _ value: String) -> Self {
        Self(operation: operation, valueArguments: valueArguments + [flag, value])
    }

    func appending(_ flag: String, _ values: [String]) -> Self {
        Self(operation: operation, valueArguments: valueArguments + values.flatMap { [flag, $0] })
    }

}

private struct HelmDeploymentState: Sendable {
    var values: HelmValueOperationState
    var createNamespace: Bool
    var dryRun: HelmDryRunMode?
    var wait: Bool
    var version: String?
    var output: HelmOutputFormat?

    init(
        settings: HelmSettings,
        createNamespace: Bool = false,
        dryRun: HelmDryRunMode? = nil,
        wait: Bool = false,
        version: String? = nil,
        output: HelmOutputFormat? = nil
    ) {
        self.values = HelmValueOperationState(settings: settings)
        self.createNamespace = createNamespace
        self.dryRun = dryRun
        self.wait = wait
        self.version = version
        self.output = output
    }

    func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { updated in
            updated.values.operation.settings.config = update(values.settings.config)
        }
    }

    func appending(_ flag: String, _ value: String) -> Self {
        modified(self) { updated in
            updated.values = values.appending(flag, value)
        }
    }

    func appending(_ flag: String, _ newValues: [String]) -> Self {
        modified(self) { updated in
            updated.values = values.appending(flag, newValues)
        }
    }

    func arguments(command: String) -> [String] {
        var arguments = values.arguments(command: command)
        if createNamespace { arguments.append("--create-namespace") }
        appendOption("--dry-run", dryRun?.rawValue, to: &arguments)
        if wait { arguments.append("--wait") }
        appendOption("--version", version, to: &arguments)
        appendOption("--output", output?.rawValue, to: &arguments)
        return arguments
    }

}
#endif
