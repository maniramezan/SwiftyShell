#if Terraform
import Foundation

/// The top-level Terraform CLI command to invoke.
public enum TerraformSubcommand: String, Sendable, Equatable, Hashable {
    /// `terraform version` — print Terraform version information.
    case version
    /// `terraform init` — initialize a working directory.
    case initialize = "init"
    /// `terraform plan` — create an execution plan.
    case plan
    /// `terraform apply` — apply infrastructure changes.
    case apply
    /// `terraform destroy` — destroy managed infrastructure.
    case destroy
    /// `terraform validate` — validate configuration files.
    case validate
    /// `terraform fmt` — rewrite configuration files to canonical format.
    case format = "fmt"
    /// `terraform output` — read output values.
    case output
    /// `terraform workspace` — manage workspaces.
    case workspace
}

/// A fluent wrapper for the Terraform CLI.
///
/// ``Terraform`` models high-value automation workflows such as `init`, `plan`,
/// `apply`, `destroy`, and `validate`, plus shared flags used in CI.
///
/// ```swift
/// try await Terraform()
///     .plan()
///     .var("region=us-central1")
///     .out("tfplan")
///     .run()
/// ```
public struct Terraform: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Terraform command family bound to a shell context.
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

    /// Returns a copy that selects a Terraform subcommand.
    public func subcommand(_ value: TerraformSubcommand) -> Self { copy(subcommand: value.rawValue, positionals: []) }

    /// Returns a copy that selects a raw Terraform subcommand.
    public func subcommand(_ value: String) -> Self { copy(subcommand: value, positionals: []) }

    /// Returns a copy configured for `terraform init`.
    public func initCommand() -> Self { subcommand(.initialize) }

    /// Returns a copy configured for `terraform plan`.
    public func plan() -> Self { subcommand(.plan) }

    /// Returns a copy configured for `terraform apply`.
    public func apply() -> Self { subcommand(.apply) }

    /// Returns a copy configured for `terraform destroy`.
    public func destroy() -> Self { subcommand(.destroy) }

    /// Returns a copy configured for `terraform validate`.
    public func validate() -> Self { subcommand(.validate) }

    /// Returns a copy configured for `terraform fmt`.
    public func format() -> Self { subcommand(.format) }

    /// Returns a copy configured for `terraform output`.
    public func output() -> Self { subcommand(.output) }

    /// Returns a copy configured for `terraform workspace <nested>`.
    public func workspace(_ nested: String? = nil) -> Self {
        var result = subcommand(.workspace)
        if let nested { result = result.positionalArgument(nested) }
        return result
    }

    /// Returns a copy that passes `-chdir=<path>` before the subcommand.
    public func chdir(_ path: String) -> Self { copy(chdirPath: path) }

    /// Returns a copy that passes `-input=<value>`.
    public func input(_ enabled: Bool) -> Self { copy(inputEnabled: enabled) }

    /// Returns a copy that passes `-no-color`.
    public func noColor(_ enabled: Bool = true) -> Self { copy(noColorEnabled: enabled) }

    /// Returns a copy that passes `-json` for commands that support machine-readable output.
    public func json(_ enabled: Bool = true) -> Self { copy(jsonEnabled: enabled) }

    /// Returns a copy that passes `-auto-approve`.
    public func autoApprove(_ enabled: Bool = true) -> Self { copy(autoApproves: enabled) }

    /// Returns a copy that passes `-refresh=<value>`.
    public func refresh(_ enabled: Bool) -> Self { copy(refreshEnabled: enabled) }

    /// Returns a copy that passes `-var <assignment>`.
    public func `var`(_ assignment: String) -> Self { copy(vars: state.vars + [assignment]) }

    /// Returns a copy that passes `-var <key=value>`.
    public func `var`(_ key: String, _ value: String) -> Self { self.var("\(key)=\(value)") }

    /// Returns a copy that passes `-var-file <path>`.
    public func varFile(_ path: String) -> Self { copy(varFiles: state.varFiles + [path]) }

    /// Returns a copy that passes `-out <path>`.
    public func out(_ path: String) -> Self { copy(outPath: path) }

    /// Returns a copy that passes `-target <address>`.
    public func target(_ address: String) -> Self { copy(targets: state.targets + [address]) }

    /// Returns a copy that appends a raw Terraform option before positional arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw Terraform options before positional arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a positional argument.
    public func positionalArgument(_ value: String) -> Self { copy(positionals: state.positionals + [value]) }

    /// Returns a copy that appends positional arguments.
    public func positionalArguments(_ values: [String]) -> Self { copy(positionals: state.positionals + values) }

    /// Builds the raw `terraform` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        if let chdirPath = state.chdirPath { arguments.append("-chdir=\(chdirPath)") }
        arguments.append(state.subcommand)
        if let inputEnabled = state.inputEnabled { arguments.append("-input=\(inputEnabled)") }
        if state.noColorEnabled { arguments.append("-no-color") }
        if state.jsonEnabled { arguments.append("-json") }
        if state.autoApproves { arguments.append("-auto-approve") }
        if let refreshEnabled = state.refreshEnabled { arguments.append("-refresh=\(refreshEnabled)") }
        for value in state.vars { arguments += ["-var", value] }
        for path in state.varFiles { arguments += ["-var-file", path] }
        if let outPath = state.outPath { arguments += ["-out", outPath] }
        for target in state.targets { arguments += ["-target", target] }
        arguments += state.extraArguments + state.positionals
        let base = Command("terraform").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: String? = nil,
        chdirPath: String?? = nil,
        inputEnabled: Bool?? = nil,
        noColorEnabled: Bool? = nil,
        jsonEnabled: Bool? = nil,
        autoApproves: Bool? = nil,
        refreshEnabled: Bool?? = nil,
        vars: [String]? = nil,
        varFiles: [String]? = nil,
        outPath: String?? = nil,
        targets: [String]? = nil,
        extraArguments: [String]? = nil,
        positionals: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                chdirPath: chdirPath ?? state.chdirPath,
                inputEnabled: inputEnabled ?? state.inputEnabled,
                noColorEnabled: noColorEnabled ?? state.noColorEnabled,
                jsonEnabled: jsonEnabled ?? state.jsonEnabled,
                autoApproves: autoApproves ?? state.autoApproves,
                refreshEnabled: refreshEnabled ?? state.refreshEnabled,
                vars: vars ?? state.vars,
                varFiles: varFiles ?? state.varFiles,
                outPath: outPath ?? state.outPath,
                targets: targets ?? state.targets,
                extraArguments: extraArguments ?? state.extraArguments,
                positionals: positionals ?? state.positionals
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let subcommand: String
    let chdirPath: String?
    let inputEnabled: Bool?
    let noColorEnabled: Bool
    let jsonEnabled: Bool
    let autoApproves: Bool
    let refreshEnabled: Bool?
    let vars: [String]
    let varFiles: [String]
    let outPath: String?
    let targets: [String]
    let extraArguments: [String]
    let positionals: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: String = TerraformSubcommand.version.rawValue,
        chdirPath: String? = nil,
        inputEnabled: Bool? = nil,
        noColorEnabled: Bool = false,
        jsonEnabled: Bool = false,
        autoApproves: Bool = false,
        refreshEnabled: Bool? = nil,
        vars: [String] = [],
        varFiles: [String] = [],
        outPath: String? = nil,
        targets: [String] = [],
        extraArguments: [String] = [],
        positionals: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.chdirPath = chdirPath
        self.inputEnabled = inputEnabled
        self.noColorEnabled = noColorEnabled
        self.jsonEnabled = jsonEnabled
        self.autoApproves = autoApproves
        self.refreshEnabled = refreshEnabled
        self.vars = vars
        self.varFiles = varFiles
        self.outPath = outPath
        self.targets = targets
        self.extraArguments = extraArguments
        self.positionals = positionals
    }
}
#endif
