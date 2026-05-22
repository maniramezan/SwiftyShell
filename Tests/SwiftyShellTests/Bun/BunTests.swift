#if Bun
import Testing
@testable import SwiftyShell

struct BunCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Bun().command()

        #expect(command.executableName == "bun")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsRunScriptCommand() {
        let command = Bun()
            .runScript("dev")
            .cwd("Example")
            .watch()
            .hot()
            .argument("--bun")
            .positionalArguments(["--port", "3000"])
            .command()

        #expect(
            command.arguments == [
                "run",
                "--cwd", "Example",
                "--watch",
                "--hot",
                "--bun",
                "dev",
                "--port", "3000",
            ]
        )
    }

    @Test func buildsModeledSubcommandsAndFlags() {
        #expect(
            Bun().install().frozenLockfile().production().command().arguments == [
                "install", "--production", "--frozen-lockfile",
            ]
        )
        #expect(Bun().add("hono", "zod").command().arguments == ["add", "hono", "zod"])
        #expect(Bun().remove(["left-pad"]).command().arguments == ["remove", "left-pad"])
        #expect(Bun().test().command().arguments == ["test"])
        #expect(
            Bun().build(["src/index.ts"]).argument("--outdir").positionalArgument("dist").command().arguments == [
                "build", "src/index.ts", "--outdir", "dist",
            ]
        )
        #expect(Bun().x("vite").command().arguments == ["x", "vite"])
        #expect(Bun().subcommand(.pm).positionalArgument("ls").command().arguments == ["pm", "ls"])
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "1.2.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Bun(context: context)
            .executable("/opt/bin/bun")
            .workingDirectory("/app")
            .timeout(5)
            .outputLimit(1024)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "1.2.0")
        #expect(command?.executableOverride == "/opt/bin/bun")
        #expect(command?.workingDirectoryOverride == "/app")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
    }
}
#endif
