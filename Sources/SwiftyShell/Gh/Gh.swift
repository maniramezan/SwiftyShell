#if Gh
import Foundation

/// The top-level `gh` command group to invoke.
public enum GhSubcommand: String, Sendable, Equatable, Hashable {
    /// `gh agent-task` — work with GitHub agent tasks.
    case agentTask = "agent-task"
    /// `gh agent` — alias for `gh agent-task`.
    case agent
    /// `gh agents` — alias for `gh agent-task`.
    case agents
    /// `gh agent-tasks` — alias for `gh agent-task`.
    case agentTasks = "agent-tasks"
    /// `gh alias` — create and manage gh aliases.
    case alias
    /// `gh api` — make authenticated GitHub API requests.
    case api
    /// `gh attestation` — work with artifact attestations.
    case attestation
    /// `gh auth` — authenticate with GitHub hosts.
    case auth
    /// `gh browse` — open GitHub resources in a browser.
    case browse
    /// `gh cache` — manage GitHub Actions caches.
    case cache
    /// `gh completion` — generate shell completions.
    case completion
    /// `gh config` — get and set gh configuration.
    case config
    /// `gh copilot` — run the GitHub Copilot CLI through gh.
    case copilot
    /// `gh extension` — manage gh extensions.
    case extensionCommand = "extension"
    /// `gh gist` — work with GitHub gists.
    case gist
    /// `gh gpg-key` — manage GPG keys.
    case gpgKey = "gpg-key"
    /// `gh issue` — work with issues.
    case issue
    /// `gh label` — manage labels.
    case label
    /// `gh licenses` — list common open source licenses.
    case licenses
    /// `gh org` — work with GitHub organizations.
    case org
    /// `gh pr` — work with pull requests.
    case pr
    /// `gh project` — work with GitHub Projects.
    case project
    /// `gh release` — work with releases.
    case release
    /// `gh repo` — work with repositories.
    case repo
    /// `gh ruleset` — view repository rulesets.
    case ruleset
    /// `gh run` — work with GitHub Actions workflow runs.
    case run
    /// `gh search` — search GitHub resources.
    case search
    /// `gh secret` — manage GitHub Actions secrets.
    case secret
    /// `gh skill` — work with GitHub skills.
    case skill
    /// `gh ssh-key` — manage SSH keys.
    case sshKey = "ssh-key"
    /// `gh status` — print account and notification status.
    case status
    /// `gh variable` — manage GitHub Actions variables.
    case variable
    /// `gh workflow` — work with GitHub Actions workflows.
    case workflow
}

/// A fluent wrapper for the GitHub CLI (`gh`).
///
/// ``Gh`` focuses on automation-friendly GitHub CLI workflows: pull requests, issues,
/// repositories, workflow runs, releases, API calls, extensions, Copilot, skills, SSH keys,
/// and agent tasks. It models the stable command shape and common global flags while preserving
/// escape hatches through ``argument(_:)`` and ``arguments(_:)`` for command-specific options.
///
/// ```swift
/// let output = try await Gh(context: context)
///     .pr("view")
///     .repo("owner/project")
///     .json(["number", "title", "state"])
///     .run()
/// ```
public struct Gh: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a GitHub CLI command family bound to a shell context.
    ///
    /// The default invocation is `gh --version`, which is safe and read-only. Select a command
    /// group with helpers such as ``pr(_:)``, ``repo(_:)``, ``workflow(_:)``, or ``api(_:)``.
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
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `gh` command's stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `gh` command's stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that prints gh version information (`gh --version`).
    public func version() -> Self { copy(versionRequested: true, subcommand: .some(nil), nestedSubcommand: .some(nil)) }

    /// Returns a copy that selects a top-level gh command group.
    public func subcommand(_ value: GhSubcommand) -> Self {
        copy(versionRequested: false, subcommand: .some(value.rawValue), nestedSubcommand: .some(nil))
    }

    /// Returns a copy that selects a raw top-level gh command group.
    public func subcommand(_ value: String) -> Self {
        copy(versionRequested: false, subcommand: .some(value), nestedSubcommand: .some(nil))
    }

    /// Returns a copy that selects a top-level command group and nested command.
    public func subcommand(_ value: GhSubcommand, _ nested: String) -> Self {
        copy(versionRequested: false, subcommand: .some(value.rawValue), nestedSubcommand: .some(nested))
    }

    /// Returns a copy that selects a raw top-level command group and nested command.
    public func subcommand(_ value: String, _ nested: String) -> Self {
        copy(versionRequested: false, subcommand: .some(value), nestedSubcommand: .some(nested))
    }

    /// Returns a copy that configures an `gh agent-task` command.
    public func agentTask(_ nested: String? = nil) -> Self { commandGroup(.agentTask, nested) }

    /// Returns a copy that configures a `gh agent` alias command.
    public func agent(_ nested: String? = nil) -> Self { commandGroup(.agent, nested) }

    /// Returns a copy that configures a `gh agents` alias command.
    public func agents(_ nested: String? = nil) -> Self { commandGroup(.agents, nested) }

    /// Returns a copy that configures a `gh agent-tasks` alias command.
    public func agentTasks(_ nested: String? = nil) -> Self { commandGroup(.agentTasks, nested) }

    /// Returns a copy that configures a `gh alias` command.
    public func alias(_ nested: String? = nil) -> Self { commandGroup(.alias, nested) }

    /// Returns a copy that configures an authenticated GitHub API request (`gh api`).
    public func api(_ endpoint: String? = nil) -> Self {
        var result = commandGroup(.api, nil)
        if let endpoint { result = result.positionalArgument(endpoint) }
        return result
    }

    /// Returns a copy that configures a `gh attestation` command.
    public func attestation(_ nested: String? = nil) -> Self { commandGroup(.attestation, nested) }

    /// Returns a copy that configures a `gh auth` command.
    public func auth(_ nested: String? = nil) -> Self { commandGroup(.auth, nested) }

    /// Returns a copy that configures a `gh browse` command.
    public func browse(_ path: String? = nil) -> Self {
        var result = commandGroup(.browse, nil)
        if let path { result = result.positionalArgument(path) }
        return result
    }

    /// Returns a copy that configures a `gh cache` command.
    public func cache(_ nested: String? = nil) -> Self { commandGroup(.cache, nested) }

    /// Returns a copy that configures a `gh completion` command.
    public func completion(_ shell: String? = nil) -> Self {
        var result = commandGroup(.completion, nil)
        if let shell { result = result.positionalArgument(shell) }
        return result
    }

    /// Returns a copy that configures a `gh config` command.
    public func config(_ nested: String? = nil) -> Self { commandGroup(.config, nested) }

    /// Returns a copy that configures a `gh copilot` command.
    public func copilot() -> Self { commandGroup(.copilot, nil) }

    /// Returns a copy that configures a `gh extension` command.
    public func extensionCommand(_ nested: String? = nil) -> Self { commandGroup(.extensionCommand, nested) }

    /// Returns a copy that configures a `gh gist` command.
    public func gist(_ nested: String? = nil) -> Self { commandGroup(.gist, nested) }

    /// Returns a copy that configures a `gh gpg-key` command.
    public func gpgKey(_ nested: String? = nil) -> Self { commandGroup(.gpgKey, nested) }

    /// Returns a copy that configures a `gh issue` command.
    public func issue(_ nested: String? = nil) -> Self { commandGroup(.issue, nested) }

    /// Returns a copy that configures a `gh label` command.
    public func label(_ nested: String? = nil) -> Self { commandGroup(.label, nested) }

    /// Returns a copy that configures a `gh licenses` command.
    public func licenses() -> Self { commandGroup(.licenses, nil) }

    /// Returns a copy that configures a `gh org` command.
    public func org(_ nested: String? = nil) -> Self { commandGroup(.org, nested) }

    /// Returns a copy that configures a `gh pr` command.
    public func pr(_ nested: String? = nil) -> Self { commandGroup(.pr, nested) }

    /// Returns a copy that configures a `gh project` command.
    public func project(_ nested: String? = nil) -> Self { commandGroup(.project, nested) }

    /// Returns a copy that configures a `gh release` command.
    public func release(_ nested: String? = nil) -> Self { commandGroup(.release, nested) }

    /// Returns a copy that configures a `gh repo` command.
    public func repoCommand(_ nested: String? = nil) -> Self { commandGroup(.repo, nested) }

    /// Returns a copy that configures a `gh ruleset` command.
    public func ruleset(_ nested: String? = nil) -> Self { commandGroup(.ruleset, nested) }

    /// Returns a copy that configures a `gh run` command.
    public func runCommand(_ nested: String? = nil) -> Self { commandGroup(.run, nested) }

    /// Returns a copy that configures a `gh search` command.
    public func search(_ nested: String? = nil) -> Self { commandGroup(.search, nested) }

    /// Returns a copy that configures a `gh secret` command.
    public func secret(_ nested: String? = nil) -> Self { commandGroup(.secret, nested) }

    /// Returns a copy that configures a `gh skill` command.
    public func skill(_ nested: String? = nil) -> Self { commandGroup(.skill, nested) }

    /// Returns a copy that configures a `gh ssh-key` command.
    public func sshKey(_ nested: String? = nil) -> Self { commandGroup(.sshKey, nested) }

    /// Returns a copy that configures a `gh status` command.
    public func status() -> Self { commandGroup(.status, nil) }

    /// Returns a copy that configures a `gh variable` command.
    public func variable(_ nested: String? = nil) -> Self { commandGroup(.variable, nested) }

    /// Returns a copy that configures a `gh workflow` command.
    public func workflow(_ nested: String? = nil) -> Self { commandGroup(.workflow, nested) }

    /// Returns a copy that passes `--repo <owner/repo>`.
    public func repo(_ ownerAndName: String) -> Self { copy(repoOverride: ownerAndName) }

    /// Returns a copy that passes `--hostname <host>`.
    public func hostname(_ value: String) -> Self { copy(hostnameOverride: value) }

    /// Returns a copy that passes `--json` with comma-separated fields.
    public func json(_ fields: [String]) -> Self { copy(jsonFields: fields) }

    /// Returns a copy that passes `--json` with comma-separated fields.
    public func json(_ fields: String...) -> Self { json(fields) }

    /// Returns a copy that passes `--jq <expression>`.
    public func jq(_ expression: String) -> Self { copy(jqExpression: expression) }

    /// Returns a copy that passes `--template <template>`.
    public func template(_ value: String) -> Self { copy(templateValue: value) }

    /// Returns a copy that passes `--limit <count>`.
    public func limit(_ count: Int) -> Self { copy(limitCount: count) }

    /// Returns a copy that passes `--web`.
    public func web(_ enabled: Bool = true) -> Self { copy(opensWeb: enabled) }

    /// Returns a copy that passes `--confirm`.
    public func confirm(_ enabled: Bool = true) -> Self { copy(confirms: enabled) }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { copy(isSilent: enabled) }

    /// Returns a copy that appends a raw option before positional arguments.
    public func option(_ name: String) -> Self { copy(extraArguments: state.extraArguments + [name]) }

    /// Returns a copy that appends a raw option and value before positional arguments.
    public func option(_ name: String, _ value: String) -> Self {
        copy(extraArguments: state.extraArguments + [name, value])
    }

    /// Returns a copy that appends a raw argument before positional arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw arguments before positional arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a positional argument after modeled and raw options.
    public func positionalArgument(_ value: String) -> Self {
        copy(positionalArguments: state.positionalArguments + [value])
    }

    /// Returns a copy that appends positional arguments after modeled and raw options.
    public func positionalArguments(_ values: [String]) -> Self {
        copy(positionalArguments: state.positionalArguments + values)
    }

    /// Builds the raw `gh` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String]

        if state.versionRequested {
            arguments = ["--version"]
        } else {
            arguments = []

            if let subcommand = state.subcommand {
                arguments.append(subcommand)
            }

            if let nestedSubcommand = state.nestedSubcommand {
                arguments.append(nestedSubcommand)
            }

            if let repoOverride = state.repoOverride {
                arguments.append("--repo")
                arguments.append(repoOverride)
            }

            if let hostnameOverride = state.hostnameOverride {
                arguments.append("--hostname")
                arguments.append(hostnameOverride)
            }

            if !state.jsonFields.isEmpty {
                arguments.append("--json")
                arguments.append(state.jsonFields.joined(separator: ","))
            }

            if let jqExpression = state.jqExpression {
                arguments.append("--jq")
                arguments.append(jqExpression)
            }

            if let templateValue = state.templateValue {
                arguments.append("--template")
                arguments.append(templateValue)
            }

            if let limitCount = state.limitCount {
                arguments.append("--limit")
                arguments.append(String(limitCount))
            }

            if state.opensWeb { arguments.append("--web") }
            if state.confirms { arguments.append("--confirm") }
            if state.isSilent { arguments.append("--silent") }

            arguments.append(contentsOf: state.extraArguments)
            arguments.append(contentsOf: state.positionalArguments)
        }

        let base = Command("gh")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func commandGroup(_ value: GhSubcommand, _ nested: String?) -> Self {
        copy(versionRequested: false, subcommand: .some(value.rawValue), nestedSubcommand: .some(nested))
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        versionRequested: Bool? = nil,
        subcommand: String?? = nil,
        nestedSubcommand: String?? = nil,
        repoOverride: String?? = nil,
        hostnameOverride: String?? = nil,
        jsonFields: [String]? = nil,
        jqExpression: String?? = nil,
        templateValue: String?? = nil,
        limitCount: Int?? = nil,
        opensWeb: Bool? = nil,
        confirms: Bool? = nil,
        isSilent: Bool? = nil,
        extraArguments: [String]? = nil,
        positionalArguments: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                versionRequested: versionRequested ?? state.versionRequested,
                subcommand: subcommand ?? state.subcommand,
                nestedSubcommand: nestedSubcommand ?? state.nestedSubcommand,
                repoOverride: repoOverride ?? state.repoOverride,
                hostnameOverride: hostnameOverride ?? state.hostnameOverride,
                jsonFields: jsonFields ?? state.jsonFields,
                jqExpression: jqExpression ?? state.jqExpression,
                templateValue: templateValue ?? state.templateValue,
                limitCount: limitCount ?? state.limitCount,
                opensWeb: opensWeb ?? state.opensWeb,
                confirms: confirms ?? state.confirms,
                isSilent: isSilent ?? state.isSilent,
                extraArguments: extraArguments ?? state.extraArguments,
                positionalArguments: positionalArguments ?? state.positionalArguments
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let versionRequested: Bool
    let subcommand: String?
    let nestedSubcommand: String?
    let repoOverride: String?
    let hostnameOverride: String?
    let jsonFields: [String]
    let jqExpression: String?
    let templateValue: String?
    let limitCount: Int?
    let opensWeb: Bool
    let confirms: Bool
    let isSilent: Bool
    let extraArguments: [String]
    let positionalArguments: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        versionRequested: Bool = true,
        subcommand: String? = nil,
        nestedSubcommand: String? = nil,
        repoOverride: String? = nil,
        hostnameOverride: String? = nil,
        jsonFields: [String] = [],
        jqExpression: String? = nil,
        templateValue: String? = nil,
        limitCount: Int? = nil,
        opensWeb: Bool = false,
        confirms: Bool = false,
        isSilent: Bool = false,
        extraArguments: [String] = [],
        positionalArguments: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.versionRequested = versionRequested
        self.subcommand = subcommand
        self.nestedSubcommand = nestedSubcommand
        self.repoOverride = repoOverride
        self.hostnameOverride = hostnameOverride
        self.jsonFields = jsonFields
        self.jqExpression = jqExpression
        self.templateValue = templateValue
        self.limitCount = limitCount
        self.opensWeb = opensWeb
        self.confirms = confirms
        self.isSilent = isSilent
        self.extraArguments = extraArguments
        self.positionalArguments = positionalArguments
    }
}
#endif
