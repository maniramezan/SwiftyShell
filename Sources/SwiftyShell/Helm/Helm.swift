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
    private let settings: HelmSettings

    /// The shell context used when running Helm operations.
    public var context: ShellContext { settings.config.context }

    /// Creates a Helm command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.settings = HelmSettings(config: ToolConfiguration(context: context))
    }

    private init(settings: HelmSettings) { self.settings = settings }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        Self(settings: settings.copy(config: update(settings.config)))
    }

    /// Returns a copy that scopes subsequent operations to a Kubernetes namespace.
    public func namespace(_ name: String) -> Self {
        Self(settings: settings.copy(namespace: name))
    }

    /// Returns a copy that uses a named kubeconfig context.
    public func kubeContext(_ name: String) -> Self {
        Self(settings: settings.copy(kubeContext: name))
    }

    /// Returns a copy that uses a specific kubeconfig file.
    public func kubeconfig(_ path: String) -> Self {
        Self(settings: settings.copy(kubeconfig: path))
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
    private let state: HelmValueOperationState
    private let name: String?
    private let chart: String
    private let outputDirectory: String?
    private let shownTemplates: [String]
    private let includeCRDsEnabled: Bool

    fileprivate init(settings: HelmSettings, name: String?, chart: String) {
        self.state = HelmValueOperationState(settings: settings)
        self.name = name
        self.chart = chart
        self.outputDirectory = nil
        self.shownTemplates = []
        self.includeCRDsEnabled = false
    }

    private init(
        state: HelmValueOperationState,
        name: String,
        chart: String,
        outputDirectory: String?,
        shownTemplates: [String],
        includeCRDsEnabled: Bool
    ) {
        self.state = state
        self.name = name.isEmpty ? nil : name
        self.chart = chart
        self.outputDirectory = outputDirectory
        self.shownTemplates = shownTemplates
        self.includeCRDsEnabled = includeCRDsEnabled
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.copy(settings: state.settings.copy(config: update(state.settings.config))))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stdout: destination))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stderr: destination))
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self { copy(state: state.appending("--values", path)) }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self { copy(state: state.appending("--values", paths)) }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-string", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        copy(state: state.appending("--set-file", "\(key)=\(path)"))
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-json", "\(key)=\(value)"))
    }

    /// Returns a copy that writes rendered files below a directory instead of stdout.
    public func outputDirectory(_ path: String) -> Self { copy(outputDirectory: path) }

    /// Returns a copy that renders only a specific chart template.
    public func showOnly(_ path: String) -> Self { copy(shownTemplates: shownTemplates + [path]) }

    /// Returns a copy that includes custom resource definitions in rendered output.
    public func includeCRDs(_ enabled: Bool = true) -> Self { copy(includeCRDsEnabled: enabled) }

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

    private func copy(
        state: HelmValueOperationState? = nil,
        outputDirectory: String?? = nil,
        shownTemplates: [String]? = nil,
        includeCRDsEnabled: Bool? = nil
    ) -> Self {
        Self(
            state: state ?? self.state,
            name: name ?? "",
            chart: chart,
            outputDirectory: outputDirectory ?? self.outputDirectory,
            shownTemplates: shownTemplates ?? self.shownTemplates,
            includeCRDsEnabled: includeCRDsEnabled ?? self.includeCRDsEnabled
        )
    }
}

/// A `helm lint` operation.
///
/// ```swift
/// try await Helm().lint(chart: "./chart").strict().withSubcharts().run()
/// ```
public struct HelmLint: RunnableCommandFamily {
    private let state: HelmValueOperationState
    private let chart: String
    private let strictEnabled: Bool
    private let quietEnabled: Bool
    private let withSubchartsEnabled: Bool
    private let kubeVersionValue: String?

    fileprivate init(settings: HelmSettings, chart: String) {
        self.state = HelmValueOperationState(settings: settings)
        self.chart = chart
        self.strictEnabled = false
        self.quietEnabled = false
        self.withSubchartsEnabled = false
        self.kubeVersionValue = nil
    }

    private init(
        state: HelmValueOperationState,
        chart: String,
        strictEnabled: Bool,
        quietEnabled: Bool,
        withSubchartsEnabled: Bool,
        kubeVersionValue: String?
    ) {
        self.state = state
        self.chart = chart
        self.strictEnabled = strictEnabled
        self.quietEnabled = quietEnabled
        self.withSubchartsEnabled = withSubchartsEnabled
        self.kubeVersionValue = kubeVersionValue
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.copy(settings: state.settings.copy(config: update(state.settings.config))))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stdout: destination))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stderr: destination))
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self { copy(state: state.appending("--values", path)) }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self { copy(state: state.appending("--values", paths)) }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-string", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        copy(state: state.appending("--set-file", "\(key)=\(path)"))
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-json", "\(key)=\(value)"))
    }

    /// Returns a copy that fails when lint warnings are emitted.
    public func strict(_ enabled: Bool = true) -> Self { copy(strictEnabled: enabled) }

    /// Returns a copy that prints only warnings and errors.
    public func quiet(_ enabled: Bool = true) -> Self { copy(quietEnabled: enabled) }

    /// Returns a copy that also lints dependent charts.
    public func withSubcharts(_ enabled: Bool = true) -> Self { copy(withSubchartsEnabled: enabled) }

    /// Returns a copy that checks capabilities and deprecations for a Kubernetes version.
    public func kubeVersion(_ version: String) -> Self { copy(kubeVersionValue: version) }

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

    private func copy(
        state: HelmValueOperationState? = nil,
        strictEnabled: Bool? = nil,
        quietEnabled: Bool? = nil,
        withSubchartsEnabled: Bool? = nil,
        kubeVersionValue: String?? = nil
    ) -> Self {
        Self(
            state: state ?? self.state,
            chart: chart,
            strictEnabled: strictEnabled ?? self.strictEnabled,
            quietEnabled: quietEnabled ?? self.quietEnabled,
            withSubchartsEnabled: withSubchartsEnabled ?? self.withSubchartsEnabled,
            kubeVersionValue: kubeVersionValue ?? self.kubeVersionValue
        )
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
    private let state: HelmDeploymentState
    private let release: String
    private let chart: String

    fileprivate init(settings: HelmSettings, release: String, chart: String) {
        self.state = HelmDeploymentState(settings: settings)
        self.release = release
        self.chart = chart
    }

    private init(state: HelmDeploymentState, release: String, chart: String) {
        self.state = state
        self.release = release
        self.chart = chart
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.values.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.updatingConfiguration(update))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(values: state.values.copy(stdout: destination)))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(values: state.values.copy(stderr: destination)))
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self { copy(state: state.appending("--values", path)) }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self { copy(state: state.appending("--values", paths)) }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-string", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        copy(state: state.appending("--set-file", "\(key)=\(path)"))
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-json", "\(key)=\(value)"))
    }

    /// Returns a copy that creates the release namespace when it is absent.
    public func createNamespace(_ enabled: Bool = true) -> Self { copy(state: state.copy(createNamespace: enabled)) }

    /// Returns a copy that performs a dry run in the selected mode.
    public func dryRun(_ mode: HelmDryRunMode) -> Self { copy(state: state.copy(dryRun: mode)) }

    /// Returns a copy that waits for resources to become ready.
    public func wait(_ enabled: Bool = true) -> Self { copy(state: state.copy(wait: enabled)) }

    /// Returns a copy that selects a chart version or version constraint.
    public func version(_ value: String) -> Self { copy(state: state.copy(version: value)) }

    /// Returns a copy that selects the command's structured output format.
    public func output(_ format: HelmOutputFormat) -> Self { copy(state: state.copy(output: format)) }

    /// Builds the raw `helm install` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "install")
        arguments += [release, chart]
        return state.values.command(arguments)
    }

    private func copy(state: HelmDeploymentState) -> Self { Self(state: state, release: release, chart: chart) }
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
    private let state: HelmDeploymentState
    private let release: String
    private let chart: String
    private let installIfMissingEnabled: Bool
    private let reuseValuesEnabled: Bool
    private let resetValuesEnabled: Bool
    private let cleanupOnFailureEnabled: Bool

    fileprivate init(settings: HelmSettings, release: String, chart: String) {
        self.state = HelmDeploymentState(settings: settings)
        self.release = release
        self.chart = chart
        self.installIfMissingEnabled = false
        self.reuseValuesEnabled = false
        self.resetValuesEnabled = false
        self.cleanupOnFailureEnabled = false
    }

    private init(
        state: HelmDeploymentState,
        release: String,
        chart: String,
        installIfMissingEnabled: Bool,
        reuseValuesEnabled: Bool,
        resetValuesEnabled: Bool,
        cleanupOnFailureEnabled: Bool
    ) {
        self.state = state
        self.release = release
        self.chart = chart
        self.installIfMissingEnabled = installIfMissingEnabled
        self.reuseValuesEnabled = reuseValuesEnabled
        self.resetValuesEnabled = resetValuesEnabled
        self.cleanupOnFailureEnabled = cleanupOnFailureEnabled
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.values.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.updatingConfiguration(update))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(values: state.values.copy(stdout: destination)))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(values: state.values.copy(stderr: destination)))
    }

    /// Returns a copy that appends a values file or URL.
    public func valuesFile(_ path: String) -> Self { copy(state: state.appending("--values", path)) }

    /// Returns a copy that appends multiple values files or URLs in precedence order.
    public func valuesFiles(_ paths: [String]) -> Self { copy(state: state.appending("--values", paths)) }

    /// Returns a copy that sets a chart value using Helm's inferred type.
    public func set(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value as a string.
    public func setString(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-string", "\(key)=\(value)"))
    }

    /// Returns a copy that sets a chart value from file contents.
    public func setFile(_ key: String, path: String) -> Self {
        copy(state: state.appending("--set-file", "\(key)=\(path)"))
    }

    /// Returns a copy that sets a chart value from JSON.
    public func setJSON(_ key: String, to value: String) -> Self {
        copy(state: state.appending("--set-json", "\(key)=\(value)"))
    }

    /// Returns a copy that installs the chart when the release does not exist.
    public func installIfMissing(_ enabled: Bool = true) -> Self { copy(installIfMissingEnabled: enabled) }

    /// Returns a copy that creates the namespace when installation is needed.
    public func createNamespace(_ enabled: Bool = true) -> Self { copy(state: state.copy(createNamespace: enabled)) }

    /// Returns a copy that merges the previous release values into new overrides.
    public func reuseValues(_ enabled: Bool = true) -> Self { copy(reuseValuesEnabled: enabled) }

    /// Returns a copy that resets values to those built into the chart.
    public func resetValues(_ enabled: Bool = true) -> Self { copy(resetValuesEnabled: enabled) }

    /// Returns a copy that removes newly created resources when the upgrade fails.
    public func cleanupOnFailure(_ enabled: Bool = true) -> Self { copy(cleanupOnFailureEnabled: enabled) }

    /// Returns a copy that performs a dry run in the selected mode.
    public func dryRun(_ mode: HelmDryRunMode) -> Self { copy(state: state.copy(dryRun: mode)) }

    /// Returns a copy that waits for resources to become ready.
    public func wait(_ enabled: Bool = true) -> Self { copy(state: state.copy(wait: enabled)) }

    /// Returns a copy that selects a chart version or version constraint.
    public func version(_ value: String) -> Self { copy(state: state.copy(version: value)) }

    /// Returns a copy that selects the command's structured output format.
    public func output(_ format: HelmOutputFormat) -> Self { copy(state: state.copy(output: format)) }

    /// Builds the raw `helm upgrade` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "upgrade")
        if installIfMissingEnabled { arguments.append("--install") }
        if reuseValuesEnabled { arguments.append("--reuse-values") }
        if resetValuesEnabled { arguments.append("--reset-values") }
        if cleanupOnFailureEnabled { arguments.append("--cleanup-on-fail") }
        arguments += [release, chart]
        return state.values.command(arguments)
    }

    private func copy(
        state: HelmDeploymentState? = nil,
        installIfMissingEnabled: Bool? = nil,
        reuseValuesEnabled: Bool? = nil,
        resetValuesEnabled: Bool? = nil,
        cleanupOnFailureEnabled: Bool? = nil
    ) -> Self {
        Self(
            state: state ?? self.state,
            release: release,
            chart: chart,
            installIfMissingEnabled: installIfMissingEnabled ?? self.installIfMissingEnabled,
            reuseValuesEnabled: reuseValuesEnabled ?? self.reuseValuesEnabled,
            resetValuesEnabled: resetValuesEnabled ?? self.resetValuesEnabled,
            cleanupOnFailureEnabled: cleanupOnFailureEnabled ?? self.cleanupOnFailureEnabled
        )
    }
}

/// A `helm uninstall` operation.
///
/// ```swift
/// try await Helm().namespace("staging").uninstall("api", "worker").wait().run()
/// ```
public struct HelmUninstall: RunnableCommandFamily {
    private let state: HelmOperationState
    private let releases: [String]
    private let dryRunEnabled: Bool
    private let keepHistoryEnabled: Bool
    private let ignoreNotFoundEnabled: Bool
    private let waitEnabled: Bool

    fileprivate init(settings: HelmSettings, releases: [String]) {
        self.state = HelmOperationState(settings: settings)
        self.releases = releases
        self.dryRunEnabled = false
        self.keepHistoryEnabled = false
        self.ignoreNotFoundEnabled = false
        self.waitEnabled = false
    }

    private init(
        state: HelmOperationState,
        releases: [String],
        dryRunEnabled: Bool,
        keepHistoryEnabled: Bool,
        ignoreNotFoundEnabled: Bool,
        waitEnabled: Bool
    ) {
        self.state = state
        self.releases = releases
        self.dryRunEnabled = dryRunEnabled
        self.keepHistoryEnabled = keepHistoryEnabled
        self.ignoreNotFoundEnabled = ignoreNotFoundEnabled
        self.waitEnabled = waitEnabled
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.copy(settings: state.settings.copy(config: update(state.settings.config))))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stdout: destination))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stderr: destination))
    }

    /// Returns a copy that simulates uninstallation.
    public func dryRun(_ enabled: Bool = true) -> Self { copy(dryRunEnabled: enabled) }

    /// Returns a copy that retains release history after removing resources.
    public func keepHistory(_ enabled: Bool = true) -> Self { copy(keepHistoryEnabled: enabled) }

    /// Returns a copy that treats missing releases as successfully uninstalled.
    public func ignoreNotFound(_ enabled: Bool = true) -> Self { copy(ignoreNotFoundEnabled: enabled) }

    /// Returns a copy that waits for resources to be removed.
    public func wait(_ enabled: Bool = true) -> Self { copy(waitEnabled: enabled) }

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

    private func copy(
        state: HelmOperationState? = nil,
        dryRunEnabled: Bool? = nil,
        keepHistoryEnabled: Bool? = nil,
        ignoreNotFoundEnabled: Bool? = nil,
        waitEnabled: Bool? = nil
    ) -> Self {
        Self(
            state: state ?? self.state,
            releases: releases,
            dryRunEnabled: dryRunEnabled ?? self.dryRunEnabled,
            keepHistoryEnabled: keepHistoryEnabled ?? self.keepHistoryEnabled,
            ignoreNotFoundEnabled: ignoreNotFoundEnabled ?? self.ignoreNotFoundEnabled,
            waitEnabled: waitEnabled ?? self.waitEnabled
        )
    }
}

/// A `helm list` operation.
///
/// ```swift
/// let output = try await Helm().list().allNamespaces().status(.deployed).output(.json).run()
/// ```
public struct HelmList: RunnableCommandFamily {
    private let state: HelmOperationState
    private let allNamespacesEnabled: Bool
    private let statuses: [HelmReleaseStatus]
    private let outputFormat: HelmOutputFormat?
    private let filterValue: String?
    private let maximum: Int?
    private let offsetValue: Int?

    fileprivate init(settings: HelmSettings) {
        self.state = HelmOperationState(settings: settings)
        self.allNamespacesEnabled = false
        self.statuses = []
        self.outputFormat = nil
        self.filterValue = nil
        self.maximum = nil
        self.offsetValue = nil
    }

    private init(
        state: HelmOperationState,
        allNamespacesEnabled: Bool,
        statuses: [HelmReleaseStatus],
        outputFormat: HelmOutputFormat?,
        filterValue: String?,
        maximum: Int?,
        offsetValue: Int?
    ) {
        self.state = state
        self.allNamespacesEnabled = allNamespacesEnabled
        self.statuses = statuses
        self.outputFormat = outputFormat
        self.filterValue = filterValue
        self.maximum = maximum
        self.offsetValue = offsetValue
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.copy(settings: state.settings.copy(config: update(state.settings.config))))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stdout: destination))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stderr: destination))
    }

    /// Returns a copy that lists releases across every namespace.
    public func allNamespaces(_ enabled: Bool = true) -> Self { copy(allNamespacesEnabled: enabled) }

    /// Returns a copy that includes releases with the selected state.
    public func status(_ value: HelmReleaseStatus) -> Self { copy(statuses: statuses + [value]) }

    /// Returns a copy that selects the command's output format.
    public func output(_ format: HelmOutputFormat) -> Self { copy(outputFormat: format) }

    /// Returns a copy that filters release names with a Perl-compatible regular expression.
    public func filter(_ expression: String) -> Self { copy(filterValue: expression) }

    /// Returns a copy that limits the number of fetched releases.
    public func max(_ count: Int) -> Self { copy(maximum: count) }

    /// Returns a copy that starts listing at a release index.
    public func offset(_ index: Int) -> Self { copy(offsetValue: index) }

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

    private func copy(
        state: HelmOperationState? = nil,
        allNamespacesEnabled: Bool? = nil,
        statuses: [HelmReleaseStatus]? = nil,
        outputFormat: HelmOutputFormat?? = nil,
        filterValue: String?? = nil,
        maximum: Int?? = nil,
        offsetValue: Int?? = nil
    ) -> Self {
        Self(
            state: state ?? self.state,
            allNamespacesEnabled: allNamespacesEnabled ?? self.allNamespacesEnabled,
            statuses: statuses ?? self.statuses,
            outputFormat: outputFormat ?? self.outputFormat,
            filterValue: filterValue ?? self.filterValue,
            maximum: maximum ?? self.maximum,
            offsetValue: offsetValue ?? self.offsetValue
        )
    }
}

/// A `helm status` operation.
///
/// ```swift
/// let output = try await Helm().status(release: "api").revision(3).output(.yaml).run()
/// ```
public struct HelmStatus: RunnableCommandFamily {
    private let state: HelmOperationState
    private let release: String
    private let outputFormat: HelmOutputFormat?
    private let revisionValue: Int?

    fileprivate init(settings: HelmSettings, release: String) {
        self.state = HelmOperationState(settings: settings)
        self.release = release
        self.outputFormat = nil
        self.revisionValue = nil
    }

    private init(state: HelmOperationState, release: String, outputFormat: HelmOutputFormat?, revisionValue: Int?) {
        self.state = state
        self.release = release
        self.outputFormat = outputFormat
        self.revisionValue = revisionValue
    }

    /// The shell context used when running this operation.
    public var context: ShellContext { state.settings.config.context }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(state: state.copy(settings: state.settings.copy(config: update(state.settings.config))))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stdout: destination))
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(state: state.copy(stderr: destination))
    }

    /// Returns a copy that selects the command's output format.
    public func output(_ format: HelmOutputFormat) -> Self { copy(outputFormat: format) }

    /// Returns a copy that displays a specific release revision.
    public func revision(_ value: Int) -> Self { copy(revisionValue: value) }

    /// Builds the raw `helm status` command.
    public func command() -> Command {
        var arguments = state.arguments(command: "status")
        appendOption("--output", outputFormat?.rawValue, to: &arguments)
        if let revisionValue { arguments += ["--revision", String(revisionValue)] }
        arguments.append(release)
        return state.command(arguments)
    }

    private func copy(
        state: HelmOperationState? = nil,
        outputFormat: HelmOutputFormat?? = nil,
        revisionValue: Int?? = nil
    ) -> Self {
        Self(
            state: state ?? self.state,
            release: release,
            outputFormat: outputFormat ?? self.outputFormat,
            revisionValue: revisionValue ?? self.revisionValue
        )
    }
}

private struct HelmSettings: Sendable {
    let config: ToolConfiguration
    let namespace: String?
    let kubeContext: String?
    let kubeconfig: String?

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

    func copy(
        config: ToolConfiguration? = nil,
        namespace: String?? = nil,
        kubeContext: String?? = nil,
        kubeconfig: String?? = nil
    ) -> Self {
        Self(
            config: config ?? self.config,
            namespace: namespace ?? self.namespace,
            kubeContext: kubeContext ?? self.kubeContext,
            kubeconfig: kubeconfig ?? self.kubeconfig
        )
    }
}

private struct HelmOperationState: Sendable {
    let settings: HelmSettings
    let stdout: OutputDestination
    let stderr: OutputDestination

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

    func copy(
        settings: HelmSettings? = nil,
        stdout: OutputDestination? = nil,
        stderr: OutputDestination? = nil
    ) -> Self {
        Self(
            settings: settings ?? self.settings,
            stdout: stdout ?? self.stdout,
            stderr: stderr ?? self.stderr
        )
    }
}

private struct HelmValueOperationState: Sendable {
    let operation: HelmOperationState
    let valueArguments: [String]

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

    func copy(
        settings: HelmSettings? = nil,
        stdout: OutputDestination? = nil,
        stderr: OutputDestination? = nil
    ) -> Self {
        Self(
            operation: operation.copy(settings: settings, stdout: stdout, stderr: stderr),
            valueArguments: valueArguments
        )
    }
}

private struct HelmDeploymentState: Sendable {
    let values: HelmValueOperationState
    let createNamespace: Bool
    let dryRun: HelmDryRunMode?
    let wait: Bool
    let version: String?
    let output: HelmOutputFormat?

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

    private init(
        values: HelmValueOperationState,
        createNamespace: Bool,
        dryRun: HelmDryRunMode?,
        wait: Bool,
        version: String?,
        output: HelmOutputFormat?
    ) {
        self.values = values
        self.createNamespace = createNamespace
        self.dryRun = dryRun
        self.wait = wait
        self.version = version
        self.output = output
    }

    func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(values: values.copy(settings: values.settings.copy(config: update(values.settings.config))))
    }

    func appending(_ flag: String, _ value: String) -> Self { copy(values: values.appending(flag, value)) }

    func appending(_ flag: String, _ newValues: [String]) -> Self {
        copy(values: values.appending(flag, newValues))
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

    func copy(
        values: HelmValueOperationState? = nil,
        createNamespace: Bool? = nil,
        dryRun: HelmDryRunMode?? = nil,
        wait: Bool? = nil,
        version: String?? = nil,
        output: HelmOutputFormat?? = nil
    ) -> Self {
        Self(
            values: values ?? self.values,
            createNamespace: createNamespace ?? self.createNamespace,
            dryRun: dryRun ?? self.dryRun,
            wait: wait ?? self.wait,
            version: version ?? self.version,
            output: output ?? self.output
        )
    }
}
#endif
