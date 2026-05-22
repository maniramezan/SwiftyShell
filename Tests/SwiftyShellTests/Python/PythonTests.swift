#if Python
import Testing
@testable import SwiftyShell

struct PythonCommandTests {
    @Test func defaultsToPython3VersionCommand() {
        let command = Python().command()

        #expect(command.executableName == "python3")
        #expect(command.arguments == ["--version"])
    }

    @Test func buildsModuleAndCommandInvocations() {
        #expect(
            Python()
                .isolated()
                .unbuffered()
                .dontWriteBytecode()
                .optimize(2)
                .option("-X")
                .option("dev")
                .module("http.server")
                .argument("8080")
                .command().arguments == [
                    "-I", "-u", "-B", "-O", "-O", "-X", "dev", "-m", "http.server", "8080",
                ]
        )

        #expect(Python().commandString("print('hi')").command().arguments == ["-c", "print('hi')"])
    }

    @Test func buildsScriptInvocationAndClampsOptimization() {
        #expect(
            Python().script("tool.py").optimize(-1).arguments(["--input", "data.json"]).command().arguments == [
                "tool.py", "--input", "data.json",
            ]
        )
    }

    @Test func repeatsOptimizationFlagForOptimizationLevel() {
        #expect(Python().script("tool.py").optimize(2).command().arguments == ["-O", "-O", "tool.py"])
    }

    @Test func negativeOptimizationLevelEmitsNoOptimizationFlags() {
        #expect(Python().script("tool.py").optimize(-1).command().arguments == ["tool.py"])
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "Python 3.13", stderr: "", exitCode: 0)
            }
        )

        let output = try await Python(context: context)
            .executable("/opt/bin/python3.13")
            .workingDirectory("/scripts")
            .timeout(5)
            .outputLimit(1024)
            .version()
            .run()

        let command = await recorder.command
        #expect(output.stdout == "Python 3.13")
        #expect(command?.executableName == "python3")
        #expect(command?.executableOverride == "/opt/bin/python3.13")
        #expect(command?.workingDirectoryOverride == "/scripts")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["--version"])
    }
}
#endif
