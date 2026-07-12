#if Kubectl
import Testing
@testable import SwiftyShell

struct KubectlCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Kubectl().command()

        #expect(command.executableName == "kubectl")
        #expect(command.arguments == ["version"])
    }

    @Test func buildsGetCommandWithSelectionFlags() {
        let command = Kubectl()
            .kubeconfig("/tmp/kubeconfig")
            .contextName("kind-local")
            .get("pods")
            .namespace("default")
            .output("json")
            .selector("app=api")
            .allNamespaces()
            .command()

        #expect(
            command.arguments == [
                "--kubeconfig", "/tmp/kubeconfig",
                "--context", "kind-local",
                "get",
                "--namespace", "default",
                "--output", "json",
                "--selector", "app=api",
                "--all-namespaces",
                "pods",
            ]
        )
    }

    @Test func buildsApplyDeleteLogsAndExecCommands() {
        #expect(Kubectl().apply().filename("deploy.yml").command().arguments == ["apply", "--filename", "deploy.yml"])
        #expect(
            Kubectl().apply().filename("a.yml").filename("b.yml").command().arguments == [
                "apply", "--filename", "a.yml", "--filename", "b.yml",
            ]
        )
        #expect(Kubectl().delete("pod/api").command().arguments == ["delete", "pod/api"])
        #expect(
            Kubectl().logs("pod/api").container("api").command().arguments == ["logs", "--container", "api", "pod/api"]
        )
        #expect(
            Kubectl().exec("pod/api", command: ["env", "--show-hidden"]).container("api").command().arguments == [
                "exec", "--container", "api", "pod/api", "--", "env", "--show-hidden",
            ]
        )
        #expect(
            Kubectl().subcommand(.rollout).positionalArguments(["status", "deployment/api"]).command().arguments == [
                "rollout", "status", "deployment/api",
            ]
        )
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "Client Version", stderr: "", exitCode: 0)
            }
        )

        let output = try await Kubectl(context: context)
            .executable("/opt/bin/kubectl")
            .workingDirectory("/cluster")
            .timeout(5)
            .outputLimit(1024)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "Client Version")
        #expect(command?.executableOverride == "/opt/bin/kubectl")
        #expect(command?.workingDirectoryOverride == "/cluster")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["version"])
    }
}
#endif
