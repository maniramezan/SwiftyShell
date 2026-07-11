#if Helm
import Testing
@testable import SwiftyShell

struct HelmCommandTests {
    @Test func buildsTemplateWithClusterAndValueOptions() {
        let command = Helm()
            .namespace("production")
            .kubeContext("prod")
            .kubeconfig("/tmp/config")
            .template(name: "api", chart: "./chart")
            .valuesFiles(["base.yaml", "prod.yaml"])
            .set("image.tag", to: "1.2.3")
            .setString("service.port", to: "080")
            .setFile("script", path: "start.sh")
            .setJSON("sidecars", to: "[]")
            .showOnly("templates/deployment.yaml")
            .includeCRDs()
            .command()

        #expect(command.executableName == "helm")
        #expect(
            command.arguments == [
                "template", "--namespace", "production", "--kube-context", "prod", "--kubeconfig", "/tmp/config",
                "--values", "base.yaml", "--values", "prod.yaml", "--set", "image.tag=1.2.3", "--set-string",
                "service.port=080", "--set-file", "script=start.sh", "--set-json", "sidecars=[]", "--show-only",
                "templates/deployment.yaml", "--include-crds", "api", "./chart",
            ]
        )
    }

    @Test func buildsLintWithOnlyLintOptions() {
        let command = Helm().lint(chart: "./chart")
            .valuesFile("values.yaml")
            .strict()
            .quiet()
            .withSubcharts()
            .kubeVersion("1.35.0")
            .command()

        #expect(
            command.arguments == [
                "lint", "--values", "values.yaml", "--strict", "--quiet", "--with-subcharts", "--kube-version",
                "1.35.0", "./chart",
            ]
        )
    }

    @Test func buildsInstallAndUpgradeOperations() {
        #expect(
            Helm().install(release: "api", chart: "repo/api")
                .createNamespace()
                .dryRun(.client)
                .wait()
                .version("2.x")
                .output(.json)
                .command().arguments == [
                    "install", "--create-namespace", "--dry-run", "client", "--wait", "--version", "2.x", "--output",
                    "json", "api", "repo/api",
                ]
        )
        #expect(
            Helm().upgrade(release: "api", chart: "repo/api")
                .valuesFile("values.yaml")
                .installIfMissing()
                .reuseValues()
                .cleanupOnFailure()
                .command().arguments == [
                    "upgrade", "--values", "values.yaml", "--install", "--reuse-values", "--cleanup-on-fail", "api",
                    "repo/api",
                ]
        )
    }

    @Test func buildsReleaseManagementOperations() {
        #expect(
            Helm().namespace("staging").uninstall("api", "worker")
                .dryRun().keepHistory().ignoreNotFound().wait().command().arguments == [
                    "uninstall", "--namespace", "staging", "--dry-run", "--keep-history", "--ignore-not-found",
                    "--wait",
                    "api", "worker",
                ]
        )
        #expect(
            Helm().list().allNamespaces().status(.deployed).status(.failed).output(.json).filter("api.*").max(20)
                .offset(10).command().arguments == [
                    "list", "--all-namespaces", "--deployed", "--failed", "--output", "json", "--filter", "api.*",
                    "--max",
                    "20", "--offset", "10",
                ]
        )
        #expect(
            Helm().status(release: "api").output(.yaml).revision(3).command().arguments == [
                "status", "--output", "yaml", "--revision", "3", "api",
            ]
        )
    }

    @Test func preservesExecutionAndOutputConfiguration() async throws {
        actor Recorder {
            var command: Command?
            func record(_ command: Command) { self.command = command }
        }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "[]", stderr: "", exitCode: 0)
            }
        )

        let output = try await Helm(context: context)
            .executable("/opt/bin/helm")
            .workingDirectory("/charts")
            .timeout(10)
            .outputLimit(2048)
            .list()
            .stdout(.tee)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "[]")
        #expect(command?.executableOverride == "/opt/bin/helm")
        #expect(command?.workingDirectoryOverride == "/charts")
        #expect(command?.timeoutOverride == 10)
        #expect(command?.outputLimitOverride == 2048)
        #expect(command?.stdoutDestination == .tee)
    }
}
#endif
