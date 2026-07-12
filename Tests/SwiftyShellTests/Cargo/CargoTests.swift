#if Cargo
import Testing
@testable import SwiftyShell

struct CargoCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Cargo().command()
        #expect(command.executableName == "cargo")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsReleaseWorkspaceCommand() {
        let command = Cargo()
            .build()
            .manifestPath("/workspace/Cargo.toml")
            .workspace()
            .features("serde", "cli")
            .noDefaultFeatures()
            .allTargets()
            .release()
            .command()

        #expect(
            command.arguments == [
                "build", "--manifest-path", "/workspace/Cargo.toml", "--workspace",
                "--features", "serde,cli", "--no-default-features", "--all-targets", "--release",
            ]
        )
    }

    @Test func buildsPackageAndTargetSelections() {
        let command = Cargo()
            .check()
            .packages(["core", "client"])
            .library()
            .binary("server")
            .example("demo")
            .testTarget("integration")
            .benchmark("throughput")
            .command()

        #expect(
            command.arguments == [
                "check", "--package", "core", "--package", "client", "--lib", "--bin", "server",
                "--example", "demo", "--test", "integration", "--bench", "throughput",
            ]
        )
    }

    @Test func separatesRunProgramArguments() {
        let command = Cargo()
            .runBinary("server")
            .release()
            .programArguments(["--port", "8080"])
            .command()

        #expect(command.arguments == ["run", "--bin", "server", "--release", "--", "--port", "8080"])
    }

    @Test func separatesTestFilterAndHarnessArguments() {
        let command = Cargo()
            .test("parser::")
            .testArguments(["--nocapture", "--test-threads", "1"])
            .command()

        #expect(command.arguments == ["test", "parser::", "--", "--nocapture", "--test-threads", "1"])
    }

    @Test func usesCargoFmtWorkspaceAndToolArgumentSyntax() {
        let command = Cargo().format().workspace().toolArgument("--check").command()
        #expect(command.arguments == ["fmt", "--all", "--", "--check"])
    }

    @Test func buildsClippyAndPackageCommands() {
        #expect(
            Cargo().clippy().allTargets().allFeatures().toolArguments(["-D", "warnings"]).command().arguments == [
                "clippy", "--all-features", "--all-targets", "--", "-D", "warnings",
            ]
        )
        #expect(Cargo().package().package("api").command().arguments == ["package", "--package", "api"])
    }

    @Test func buildsModeledAndCustomSubcommands() {
        let cases: [(CargoSubcommand, String)] = [
            (.version, "--version"), (.build, "build"), (.test, "test"), (.check, "check"),
            (.run, "run"), (.format, "fmt"), (.clippy, "clippy"), (.package, "package"),
            (.custom("metadata"), "metadata"),
        ]
        for (subcommand, expected) in cases {
            #expect(Cargo().subcommand(subcommand).command().arguments == [expected])
        }
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder {
            var command: Command?
            func record(_ command: Command) { self.command = command }
        }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "cargo 1.88.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Cargo(context: context)
            .executable("/opt/rust/bin/cargo")
            .workingDirectory("/workspace")
            .timeout(5)
            .outputLimit(1024)
            .version()
            .run()

        let command = await recorder.command
        #expect(output.stdout == "cargo 1.88.0")
        #expect(command?.executableName == "cargo")
        #expect(command?.executableOverride == "/opt/rust/bin/cargo")
        #expect(command?.workingDirectoryOverride == "/workspace")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
    }
}
#endif
