#if Gh
import Testing
@testable import SwiftyShell

struct GhCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Gh().command()

        #expect(command.executableName == "gh")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsPullRequestViewCommandWithFormatting() {
        let command = Gh()
            .pr("view")
            .repo("owner/project")
            .json(["number", "title", "state"])
            .jq(".title")
            .template("{{.number}}")
            .command()

        #expect(
            command.arguments == [
                "pr", "view",
                "--repo", "owner/project",
                "--json", "number,title,state",
                "--jq", ".title",
                "--template", "{{.number}}",
            ]
        )
    }

    @Test func buildsAutomationSubcommands() {
        let cases: [(GhSubcommand, String)] = [
            (.agentTask, "agent-task"),
            (.agent, "agent"),
            (.agents, "agents"),
            (.agentTasks, "agent-tasks"),
            (.alias, "alias"),
            (.api, "api"),
            (.attestation, "attestation"),
            (.auth, "auth"),
            (.browse, "browse"),
            (.cache, "cache"),
            (.completion, "completion"),
            (.config, "config"),
            (.copilot, "copilot"),
            (.extensionCommand, "extension"),
            (.gist, "gist"),
            (.gpgKey, "gpg-key"),
            (.issue, "issue"),
            (.label, "label"),
            (.licenses, "licenses"),
            (.org, "org"),
            (.pr, "pr"),
            (.project, "project"),
            (.release, "release"),
            (.repo, "repo"),
            (.ruleset, "ruleset"),
            (.run, "run"),
            (.search, "search"),
            (.secret, "secret"),
            (.skill, "skill"),
            (.sshKey, "ssh-key"),
            (.status, "status"),
            (.variable, "variable"),
            (.workflow, "workflow"),
        ]

        for (subcommand, expected) in cases {
            #expect(Gh().subcommand(subcommand).command().arguments == [expected])
        }
    }

    @Test func buildsAgentTaskAliases() {
        #expect(
            Gh().agentTask("create").positionalArgument("Fix flaky tests").command().arguments == [
                "agent-task", "create", "Fix flaky tests",
            ]
        )
        #expect(Gh().agent("list").limit(5).command().arguments == ["agent", "list", "--limit", "5"])
        #expect(Gh().agents("view").positionalArgument("123").command().arguments == ["agents", "view", "123"])
        #expect(
            Gh().agentTasks("view").positionalArgument("abc").command().arguments == [
                "agent-tasks", "view", "abc",
            ]
        )
    }

    @Test func buildsApiRequestWithRawOptions() {
        let command = Gh()
            .api("repos/owner/project/issues")
            .hostname("github.example.com")
            .option("--method", "POST")
            .option("--field")
            .argument("title=Bug")
            .command()

        #expect(
            command.arguments == [
                "api", "--hostname", "github.example.com", "--method", "POST", "--field", "title=Bug",
                "repos/owner/project/issues",
            ]
        )
    }

    @Test func buildsCopilotCommandWithPassthroughArguments() {
        let command = Gh()
            .copilot()
            .arguments(["-p", "Summarize commits", "--allow-tool", "shell(git)"])
            .command()

        #expect(command.arguments == ["copilot", "-p", "Summarize commits", "--allow-tool", "shell(git)"])
    }

    @Test func buildsSkillExtensionAndSshKeyCommands() {
        #expect(Gh().skill("search").positionalArgument("swift").command().arguments == ["skill", "search", "swift"])
        #expect(
            Gh().extensionCommand("install").positionalArgument("owner/gh-tool").command().arguments == [
                "extension", "install", "owner/gh-tool",
            ]
        )
        #expect(
            Gh().repoCommand("view").positionalArgument("owner/project").command().arguments == [
                "repo", "view", "owner/project",
            ]
        )
        #expect(Gh().sshKey("list").command().arguments == ["ssh-key", "list"])
    }

    @Test func buildsCommonFlagsAndPositionalsInStableOrder() {
        let command = Gh()
            .workflow("run")
            .repo("owner/project")
            .web()
            .confirm()
            .silent()
            .positionalArgument("ci.yml")
            .command()

        #expect(
            command.arguments == [
                "workflow", "run", "--repo", "owner/project", "--web", "--confirm", "--silent", "ci.yml",
            ]
        )
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder {
            var command: Command?
            var workingDirectory: String?

            func record(_ command: Command, context: ShellContext) {
                self.command = command
                self.workingDirectory = context.workingDirectory
            }
        }

        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, context in
                await recorder.record(command, context: context)
                return ShellOutput(stdout: "gh version 2.0.0\n", stderr: "", exitCode: 0)
            },
            workingDirectory: "/context"
        )

        let output = try await Gh(context: context)
            .executable("/opt/homebrew/bin/gh")
            .workingDirectory("/override")
            .timeout(.seconds(5))
            .outputLimit(1024)
            .version()
            .run()

        let command = await recorder.command
        #expect(output.stdout == "gh version 2.0.0\n")
        #expect(command?.executableName == "gh")
        #expect(command?.executableOverride == "/opt/homebrew/bin/gh")
        #expect(command?.workingDirectoryOverride == "/override")
        #expect(command?.timeoutOverride == .seconds(5))
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
        #expect(await recorder.workingDirectory == "/context")
    }
}

/// Every Boolean flag setter adds exactly its flag when enabled and removes it when disabled.
struct GhFlagSetterTests {
    @Test func eachFlagSetterTogglesItsFlag() {
        let base = Gh().issue("list")
        let setters: [(flag: String, set: (Gh, Bool) -> Gh)] = [
            ("--web", { $0.web($1) }),
            ("--confirm", { $0.confirm($1) }),
            ("--silent", { $0.silent($1) }),
        ]
        for (flag, set) in setters {
            #expect(!base.command().arguments.contains(flag), "\(flag) present before enabling")
            let enabled = set(base, true)
            #expect(enabled.command().arguments.contains(flag), "\(flag) missing after enabling")
            #expect(!set(enabled, false).command().arguments.contains(flag), "\(flag) kept after disabling")
        }
    }
}

struct GhCommandGroupTests {
    @Test func commandGroupsBuildTheirArgv() {
        let cases: [(Gh, [String])] = [
            (Gh().alias("list"), ["alias", "list"]), (Gh().attestation("verify"), ["attestation", "verify"]),
            (Gh().auth("status"), ["auth", "status"]), (Gh().browse("README.md"), ["browse", "README.md"]),
            (Gh().cache("list"), ["cache", "list"]), (Gh().completion("zsh"), ["completion", "zsh"]),
            (Gh().config("get"), ["config", "get"]), (Gh().gist("list"), ["gist", "list"]),
            (Gh().gpgKey("list"), ["gpg-key", "list"]), (Gh().issue("list"), ["issue", "list"]),
            (Gh().label("list"), ["label", "list"]), (Gh().licenses(), ["licenses"]),
            (Gh().org("list"), ["org", "list"]), (Gh().project("list"), ["project", "list"]),
            (Gh().release("list"), ["release", "list"]), (Gh().ruleset("list"), ["ruleset", "list"]),
            (Gh().runCommand("list"), ["run", "list"]), (Gh().search("repos"), ["search", "repos"]),
            (Gh().secret("list"), ["secret", "list"]), (Gh().status(), ["status"]),
            (Gh().variable("list"), ["variable", "list"]),
            (Gh().issue("list").json("number", "title"), ["issue", "list", "--json", "number,title"]),
            (Gh().subcommand("repo", "view").positionalArguments(["cli/cli"]), ["repo", "view", "cli/cli"]),
        ]
        for (gh, expected) in cases {
            #expect(gh.command().arguments == expected)
        }
    }
}
#endif
