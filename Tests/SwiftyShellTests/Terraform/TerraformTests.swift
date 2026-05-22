#if Terraform
import Testing
@testable import SwiftyShell

struct TerraformCommandTests {
    @Test func defaultsToVersionCommand() {
        let command = Terraform().command()

        #expect(command.executableName == "terraform")
        #expect(command.arguments == ["version"])
    }

    @Test func buildsPlanCommandWithAutomationFlags() {
        let command = Terraform()
            .chdir("infra")
            .plan()
            .input(false)
            .noColor()
            .refresh(false)
            .var("region=us-central1")
            .varFile("prod.tfvars")
            .out("tfplan")
            .target("module.api")
            .argument("-lock=false")
            .command()

        #expect(
            command.arguments == [
                "-chdir=infra",
                "plan",
                "-input=false",
                "-no-color",
                "-refresh=false",
                "-var", "region=us-central1",
                "-var-file", "prod.tfvars",
                "-out", "tfplan",
                "-target", "module.api",
                "-lock=false",
            ]
        )
    }

    @Test func buildsPlanCommandWithVariablesPlanOutputTargetsAndPositionals() {
        let command = Terraform()
            .plan()
            .var("region", "us-central1")
            .varFile("prod.tfvars")
            .out("plan.out")
            .target("module.api")
            .positionalArgument("infra")
            .command()

        #expect(
            command.arguments == [
                "plan",
                "-var", "region=us-central1",
                "-var-file", "prod.tfvars",
                "-out", "plan.out",
                "-target", "module.api",
                "infra",
            ]
        )
    }

    @Test func buildsModeledSubcommands() {
        #expect(Terraform().initCommand().command().arguments == ["init"])
        #expect(
            Terraform().apply().autoApprove().positionalArgument("tfplan").command().arguments == [
                "apply", "-auto-approve", "tfplan",
            ]
        )
        #expect(Terraform().apply().autoApprove().json().command().arguments == ["apply", "-json", "-auto-approve"])
        #expect(Terraform().destroy().autoApprove().command().arguments == ["destroy", "-auto-approve"])
        #expect(Terraform().validate().command().arguments == ["validate"])
        #expect(Terraform().format().command().arguments == ["fmt"])
        #expect(Terraform().output().json().command().arguments == ["output", "-json"])
        #expect(
            Terraform().workspace("select").positionalArgument("prod").command().arguments == [
                "workspace", "select", "prod",
            ]
        )
        #expect(Terraform().subcommand("state").positionalArguments(["list"]).command().arguments == ["state", "list"])
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder { var command: Command?; func record(_ command: Command) { self.command = command } }
        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "Terraform v1.0.0", stderr: "", exitCode: 0)
            }
        )

        let output = try await Terraform(context: context)
            .executable("/opt/bin/terraform")
            .workingDirectory("/infra")
            .timeout(5)
            .outputLimit(1024)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "Terraform v1.0.0")
        #expect(command?.executableOverride == "/opt/bin/terraform")
        #expect(command?.workingDirectoryOverride == "/infra")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["version"])
    }
}
#endif
