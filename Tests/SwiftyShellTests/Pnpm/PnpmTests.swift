#if Pnpm
import Testing
@testable import SwiftyShell

struct PnpmCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Pnpm().command()

        #expect(command.executableName == "pnpm")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsRunScriptCommand() {
        let command = Pnpm()
            .runScript("build")
            .directory("Example")
            .filter("./packages/app")
            .recursive()
            .ifPresent()
            .argument("--stream")
            .positionalArguments(["--mode", "production"])
            .command()

        #expect(
            command.arguments == [
                "run",
                "--dir", "Example",
                "--filter", "./packages/app",
                "--recursive",
                "--if-present",
                "--stream",
                "build",
                "--mode", "production",
            ]
        )
    }

    @Test func buildsModeledSubcommandsAndFlags() {
        #expect(
            Pnpm().install().frozenLockfile().production().command().arguments == [
                "install", "--frozen-lockfile", "--prod",
            ]
        )
        #expect(Pnpm().add("left-pad", "vite").command().arguments == ["add", "left-pad", "vite"])
        #expect(Pnpm().remove(["left-pad"]).command().arguments == ["remove", "left-pad"])
        #expect(Pnpm().test().command().arguments == ["test"])
        #expect(Pnpm().exec("vite").json().command().arguments == ["exec", "--json", "vite"])
        #expect(Pnpm().dlx("create-vite").command().arguments == ["dlx", "create-vite"])
        #expect(Pnpm().subcommand(.audit).command().arguments == ["audit"])
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "11.0.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Pnpm(context: context)
            .executable("/opt/bin/pnpm")
            .workingDirectory("/app")
            .timeout(5)
            .outputLimit(1024)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "11.0.0")
        #expect(command?.executableOverride == "/opt/bin/pnpm")
        #expect(command?.workingDirectoryOverride == "/app")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
    }
}
#endif
