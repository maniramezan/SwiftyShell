#if Node
import Testing
@testable import SwiftyShell

struct NodeCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Node().command()

        #expect(command.executableName == "node")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsEvalAndPrintCommands() {
        #expect(
            Node()
                .require("dotenv/config")
                .inspect()
                .watch()
                .argument("--trace-warnings")
                .eval("console.log(process.version)")
                .scriptArgument("--verbose")
                .command().arguments == [
                    "--require", "dotenv/config",
                    "--inspect",
                    "--watch",
                    "--trace-warnings",
                    "--eval", "console.log(process.version)",
                    "--verbose",
                ]
        )

        #expect(Node().printExpression("1 + 1").command().arguments == ["--print", "1 + 1"])
    }

    @Test func buildsCheckAndScriptCommands() {
        #expect(Node().check("index.js").command().arguments == ["--check", "index.js"])
        #expect(
            Node().script("server.js").scriptArguments(["--port", "3000"]).command().arguments == [
                "server.js", "--port", "3000",
            ]
        )
    }

    @Test func placesRequiredModulesBeforeScriptPath() {
        #expect(
            Node().script("server.js").require("dotenv/config").command().arguments == [
                "--require", "dotenv/config", "server.js",
            ]
        )
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "v22.0.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Node(context: context)
            .executable("/opt/bin/node")
            .workingDirectory("/app")
            .timeout(5)
            .outputLimit(1024)
            .version()
            .run()

        let command = await recorder.command
        #expect(output.stdout == "v22.0.0")
        #expect(command?.executableOverride == "/opt/bin/node")
        #expect(command?.workingDirectoryOverride == "/app")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
    }
}
#endif
