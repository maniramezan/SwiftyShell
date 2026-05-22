#if Make
import Testing
@testable import SwiftyShell

struct MakeCommandTests {
    @Test func buildsDefaultMakeCommand() {
        let command = Make().command()

        #expect(command.executableName == "make")
        #expect(command.arguments == [])
    }

    @Test func buildsMakeCommandWithCommonOptionsAndTargets() {
        let command = Make()
            .file("Build.mk")
            .directory("Example")
            .jobs(8)
            .keepGoing()
            .silent()
            .dryRun()
            .alwaysMake()
            .argument("CONFIG=release")
            .target("check")
            .targets(["package", "deploy"])
            .command()

        #expect(
            command.arguments == [
                "--file", "Build.mk",
                "--directory", "Example",
                "--jobs", "8",
                "--keep-going",
                "--silent",
                "--dry-run",
                "--always-make",
                "CONFIG=release",
                "check", "package", "deploy",
            ]
        )
    }

    @Test func serializesJobCountAsSeparateArgument() {
        #expect(Make().jobs(8).command().arguments == ["--jobs", "8"])
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
                return ShellOutput(stdout: "ok", stderr: "", exitCode: 0)
            }
        )

        let output = try await Make(context: context)
            .executable("/usr/bin/make")
            .workingDirectory("/repo")
            .timeout(5)
            .outputLimit(1024)
            .target("check")
            .run()

        let command = await recorder.command
        #expect(output.stdout == "ok")
        #expect(command?.executableName == "make")
        #expect(command?.executableOverride == "/usr/bin/make")
        #expect(command?.workingDirectoryOverride == "/repo")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["check"])
    }
}
#endif
