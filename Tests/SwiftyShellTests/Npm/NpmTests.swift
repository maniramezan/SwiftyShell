#if Npm
import Testing
@testable import SwiftyShell

struct NpmCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Npm().command()

        #expect(command.executableName == "npm")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsRunScriptCommand() {
        let command = Npm()
            .runScript("build")
            .prefix("Example")
            .ifPresent()
            .silent()
            .argument("--")
            .positionalArguments(["--mode", "production"])
            .command()

        #expect(
            command.arguments == [
                "run",
                "--prefix", "Example",
                "--if-present",
                "--silent",
                "--",
                "build",
                "--mode", "production",
            ]
        )
    }

    @Test func buildsModeledSubcommandsAndFlags() {
        #expect(
            Npm().install().production().positionalArgument("left-pad").command().arguments == [
                "install", "--production", "left-pad",
            ]
        )
        #expect(Npm().ci().command().arguments == ["ci"])
        #expect(Npm().test().command().arguments == ["test"])
        #expect(Npm().exec("vite").global().json().command().arguments == ["exec", "--global", "--json", "vite"])
        #expect(Npm().subcommand(.audit).command().arguments == ["audit"])
        #expect(
            Npm().subcommand("view").positionalArgument("swift-shell").command().arguments == ["view", "swift-shell"]
        )
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "10.0.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Npm(context: context)
            .executable("/opt/bin/npm")
            .workingDirectory("/app")
            .timeout(5)
            .outputLimit(1024)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "10.0.0")
        #expect(command?.executableOverride == "/opt/bin/npm")
        #expect(command?.workingDirectoryOverride == "/app")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
    }
}
#endif
