#if Swift
import Testing
@testable import SwiftyShell

struct SwiftCommandTests {
    @Test func switchingSubcommandClearsPackageSubcommand() {
        #expect(Swift().package("resolve").subcommand(.build).command().arguments == ["build"])
    }

    @Test func defaultsToVersionCommand() {
        let command = Swift().command()

        #expect(command.executableName == "swift")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsReleasePackageBuildCommand() {
        let command = Swift()
            .build()
            .packagePath("/workspace")
            .scratchPath("/tmp/build")
            .configuration(.release)
            .product("SwiftyShell")
            .traits("Git", "Rsync")
            .disableDefaultTraits()
            .jobs(8)
            .swiftCompilerFlag("-warnings-as-errors")
            .command()

        #expect(
            command.arguments == [
                "build",
                "--package-path", "/workspace",
                "--scratch-path", "/tmp/build",
                "--configuration", "release",
                "--product", "SwiftyShell",
                "--traits", "Git,Rsync",
                "--disable-default-traits",
                "--jobs", "8",
                "-Xswiftc", "-warnings-as-errors",
            ]
        )
    }

    @Test func buildsTestCommandWithCoverageAndFilters() {
        let command = Swift()
            .test()
            .enableAllTraits()
            .codeCoverage()
            .skipBuild()
            .listTests()
            .filter("CommandTests")
            .skip("SlowTests")
            .command()

        #expect(
            command.arguments == [
                "test",
                "--enable-all-traits",
                "--enable-code-coverage",
                "--skip-build",
                "--list-tests",
                "--filter", "CommandTests",
                "--skip", "SlowTests",
            ]
        )
    }

    @Test func buildsRunCommandWithProductAndExecutableArguments() {
        let command = Swift()
            .runProduct("tool")
            .configuration(.debug)
            .positionalArguments(["--input", "file.txt"])
            .command()

        #expect(command.arguments == ["run", "--configuration", "debug", "tool", "--input", "file.txt"])
    }

    @Test func buildsPackageSubcommandAndRawPluginArguments() {
        let command = Swift()
            .package("generate-documentation")
            .argument("--target")
            .argument("SwiftyShell")
            .command()

        #expect(command.arguments == ["package", "generate-documentation", "--target", "SwiftyShell"])
    }

    @Test func buildsCompilerAndLinkerFlagForwarding() {
        let command = Swift()
            .build()
            .swiftCompilerFlags(["-warnings-as-errors", "-strict-concurrency=complete"])
            .cCompilerFlag("-DDEBUG")
            .linkerFlag("-dead_strip")
            .command()

        #expect(
            command.arguments == [
                "build",
                "-Xswiftc", "-warnings-as-errors",
                "-Xswiftc", "-strict-concurrency=complete",
                "-Xcc", "-DDEBUG",
                "-Xlinker", "-dead_strip",
            ]
        )
    }

    @Test func buildsModeledAndCustomSubcommands() {
        let cases: [(SwiftSubcommand, String)] = [
            (.version, "--version"),
            (.build, "build"),
            (.test, "test"),
            (.run, "run"),
            (.package, "package"),
            (.repl, "repl"),
            (.custom("format"), "format"),
        ]

        for (subcommand, expected) in cases {
            #expect(Swift().subcommand(subcommand).command().arguments == [expected])
        }
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
                return ShellOutput(stdout: "Swift version 6.1\n", stderr: "", exitCode: 0)
            },
            workingDirectory: "/context"
        )

        let output = try await Swift(context: context)
            .executable("/usr/bin/swift")
            .workingDirectory("/override")
            .timeout(.seconds(5))
            .outputLimit(1024)
            .version()
            .run()

        let command = await recorder.command
        #expect(output.stdout == "Swift version 6.1\n")
        #expect(command?.executableName == "swift")
        #expect(command?.executableOverride == "/usr/bin/swift")
        #expect(command?.workingDirectoryOverride == "/override")
        #expect(command?.timeoutOverride == .seconds(5))
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
        #expect(await recorder.workingDirectory == "/context")
    }

    @Test func runsSwiftVersionWhenAvailable() async throws {
        let output = try await Swift().version().run()

        #expect(output.exitCode == 0)
        #expect(output.stdout.contains("Swift"))
    }
}

/// Every Boolean flag setter adds exactly its flag when enabled and removes it when disabled.
struct SwiftFlagSetterTests {
    @Test func eachFlagSetterTogglesItsFlag() {
        let base = Swift()
        let setters: [(flag: String, set: (Swift, Bool) -> Swift)] = [
            ("--enable-all-traits", { $0.enableAllTraits($1) }),
            ("--disable-default-traits", { $0.disableDefaultTraits($1) }),
            ("--build-tests", { $0.buildTests($1) }),
            ("--enable-code-coverage", { $0.codeCoverage($1) }),
            ("--skip-build", { $0.skipBuild($1) }),
            ("--list-tests", { $0.listTests($1) }),
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
