#if Docker
import Testing
@testable import SwiftyShell

struct DockerCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Docker().command()

        #expect(command.executableName == "docker")
        #expect(command.arguments == ["version"])
    }

    @Test func buildsGlobalOptionsBeforeSubcommand() {
        let command = Docker()
            .configPath("/tmp/docker")
            .context("desktop-linux")
            .host("ssh://user@example.com")
            .logLevel("debug")
            .debugMode()
            .tls()
            .tlsVerify()
            .system("info")
            .format("json")
            .command()

        #expect(
            command.arguments == [
                "--config", "/tmp/docker",
                "--context", "desktop-linux",
                "--host", "ssh://user@example.com",
                "--log-level", "debug",
                "--debug",
                "--tls",
                "--tlsverify",
                "system", "info",
                "--format", "json",
            ]
        )
    }

    @Test func buildsModeledSubcommands() {
        let cases: [(DockerSubcommand, String)] = [
            (.builder, "builder"),
            (.buildx, "buildx"),
            (.checkpoint, "checkpoint"),
            (.compose, "compose"),
            (.config, "config"),
            (.container, "container"),
            (.context, "context"),
            (.debug, "debug"),
            (.desktop, "desktop"),
            (.dhi, "dhi"),
            (.image, "image"),
            (.initialize, "init"),
            (.inspect, "inspect"),
            (.login, "login"),
            (.logout, "logout"),
            (.manifest, "manifest"),
            (.mcp, "mcp"),
            (.model, "model"),
            (.network, "network"),
            (.node, "node"),
            (.offload, "offload"),
            (.pass, "pass"),
            (.plugin, "plugin"),
            (.sandbox, "sandbox"),
            (.scout, "scout"),
            (.search, "search"),
            (.secret, "secret"),
            (.service, "service"),
            (.stack, "stack"),
            (.swarm, "swarm"),
            (.system, "system"),
            (.trust, "trust"),
            (.version, "version"),
            (.volume, "volume"),
        ]

        for (subcommand, expected) in cases {
            #expect(Docker().subcommand(subcommand).command().arguments == [expected])
        }
    }

    @Test func buildsBuildxBuildCommand() {
        let command = Docker()
            .buildx("build")
            .platform("linux/amd64,linux/arm64")
            .file("Dockerfile.release")
            .tag("owner/app:latest")
            .tags(["owner/app:1.0", "owner/app:stable"])
            .buildArg("SWIFT_VERSION=6.1")
            .buildArgs(["CONFIGURATION=release"])
            .progress(.plain)
            .push()
            .positionalArgument(".")
            .command()

        #expect(
            command.arguments == [
                "buildx", "build",
                "--platform", "linux/amd64,linux/arm64",
                "--file", "Dockerfile.release",
                "--tag", "owner/app:latest",
                "--tag", "owner/app:1.0",
                "--tag", "owner/app:stable",
                "--build-arg", "SWIFT_VERSION=6.1",
                "--build-arg", "CONFIGURATION=release",
                "--progress", "plain",
                "--push",
                ".",
            ]
        )
    }

    @Test func buildsRunAndContainerCommands() {
        let runCommand = Docker()
            .subcommand("run")
            .name("web")
            .removeWhenDone()
            .detach()
            .interactive()
            .tty()
            .positionalArguments(["nginx", "nginx", "-g", "daemon off;"])
            .command()

        #expect(
            runCommand.arguments == [
                "run", "--name", "web", "--rm", "--detach", "--interactive", "--tty", "nginx", "nginx", "-g",
                "daemon off;",
            ]
        )

        #expect(Docker().container("ls").format("json").command().arguments == ["container", "ls", "--format", "json"])
        #expect(
            Docker().image("pull").platform("linux/arm64").positionalArgument("swift:6.1").command().arguments == [
                "image", "pull", "--platform", "linux/arm64", "swift:6.1",
            ]
        )
    }

    @Test func buildsDebugMcpScoutAndInitCommands() {
        #expect(
            Docker().debug("nginx").shell("bash").commandString("cat /etc/os-release").command().arguments == [
                "debug", "--command", "cat /etc/os-release", "--shell", "bash", "nginx",
            ]
        )
        #expect(Docker().mcp("server").argument("list").command().arguments == ["mcp", "server", "list"])
        #expect(
            Docker().scout("cves").positionalArgument("owner/app:latest").command().arguments == [
                "scout", "cves", "owner/app:latest",
            ]
        )
        #expect(Docker().initialize().command().arguments == ["init"])
    }

    @Test func buildsComposeAndRawOptions() {
        let command = Docker()
            .compose("up")
            .option("--file", "compose.ci.yml")
            .option("--profile")
            .argument("test")
            .argument("--build")
            .positionalArgument("api")
            .command()

        #expect(
            command.arguments == ["compose", "up", "--file", "compose.ci.yml", "--profile", "test", "--build", "api"]
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
                return ShellOutput(stdout: "Docker version 28.0.0\n", stderr: "", exitCode: 0)
            },
            workingDirectory: "/context"
        )

        let output = try await Docker(context: context)
            .executable("/usr/local/bin/docker")
            .workingDirectory("/override")
            .timeout(5)
            .outputLimit(1024)
            .version()
            .run()

        let command = await recorder.command
        #expect(output.stdout == "Docker version 28.0.0\n")
        #expect(command?.executableName == "docker")
        #expect(command?.executableOverride == "/usr/local/bin/docker")
        #expect(command?.workingDirectoryOverride == "/override")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["version"])
        #expect(await recorder.workingDirectory == "/context")
    }
}
#endif
