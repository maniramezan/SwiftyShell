#if Yarn
import Testing
@testable import SwiftyShell

struct YarnCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Yarn().command()

        #expect(command.executableName == "yarn")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsRunScriptCommand() {
        let command = Yarn()
            .runScript("build")
            .cwd("Example")
            .immutable()
            .silent()
            .argument("--inspect")
            .positionalArguments(["--mode", "production"])
            .command()

        #expect(
            command.arguments == [
                "run",
                "--cwd", "Example",
                "--immutable",
                "--silent",
                "--inspect",
                "build",
                "--mode", "production",
            ]
        )
    }

    @Test func buildsModeledSubcommandsAndFlags() {
        #expect(Yarn().install().production().command().arguments == ["install", "--production"])
        #expect(Yarn().add("left-pad", "vite").command().arguments == ["add", "left-pad", "vite"])
        #expect(Yarn().remove(["left-pad"]).command().arguments == ["remove", "left-pad"])
        #expect(Yarn().test().command().arguments == ["test"])
        #expect(Yarn().exec("vite").json().command().arguments == ["exec", "--json", "vite"])
        #expect(Yarn().dlx("create-vite").command().arguments == ["dlx", "create-vite"])
        #expect(
            Yarn().subcommand(.workspaces).positionalArgument("list").command().arguments == ["workspaces", "list"]
        )
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "4.0.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Yarn(context: context)
            .executable("/opt/bin/yarn")
            .workingDirectory("/app")
            .timeout(5)
            .outputLimit(1024)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "4.0.0")
        #expect(command?.executableOverride == "/opt/bin/yarn")
        #expect(command?.workingDirectoryOverride == "/app")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
    }
}
#endif
