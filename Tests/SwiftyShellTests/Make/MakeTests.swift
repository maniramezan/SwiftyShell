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
        let mock = MockExecutor { _, _ in ShellOutput(stdout: "ok", stderr: "", exitCode: 0) }
        let context = ShellContext(executor: mock)

        let output = try await Make(context: context)
            .executable("/usr/bin/make")
            .workingDirectory("/repo")
            .timeout(.seconds(5))
            .outputLimit(1024)
            .target("check")
            .run()

        let command = mock.recordedCommands.last
        #expect(output.stdout == "ok")
        #expect(command?.executableName == "make")
        #expect(command?.executableOverride == "/usr/bin/make")
        #expect(command?.workingDirectoryOverride == "/repo")
        #expect(command?.timeoutOverride == .seconds(5))
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["check"])
    }
}

/// Every Boolean flag setter adds exactly its flag when enabled and removes it when disabled.
struct MakeFlagSetterTests {
    @Test func eachFlagSetterTogglesItsFlag() {
        let base = Make()
        let setters: [(flag: String, set: (Make, Bool) -> Make)] = [
            ("--keep-going", { $0.keepGoing($1) }),
            ("--silent", { $0.silent($1) }),
            ("--dry-run", { $0.dryRun($1) }),
            ("--always-make", { $0.alwaysMake($1) }),
        ]
        for (flag, set) in setters {
            #expect(!base.command().arguments.contains(flag), "\(flag) present before enabling")
            let enabled = set(base, true)
            #expect(enabled.command().arguments.contains(flag), "\(flag) missing after enabling")
            #expect(!set(enabled, false).command().arguments.contains(flag), "\(flag) kept after disabling")
        }
    }
}
#endif
