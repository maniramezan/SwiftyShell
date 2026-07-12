#if Curl
import Foundation
import Testing
@testable import SwiftyShell

struct CurlTests {
    @Test func defaultsToVersionWithoutLoadingCurlConfiguration() {
        let command = Curl().command()

        #expect(command.executableName == "curl")
        #expect(command.arguments == ["--disable", "--version"])
    }

    @Test func buildsTypedRequestWithHeadersAndBody() {
        let command = Curl("https://example.com/items")
            .method(.post)
            .header(name: "Accept", value: "application/json")
            .header(name: "Content-Type", value: "application/json")
            .headerFile("/run/secrets/api-headers")
            .body(#"{"name":"sample"}"#)
            .command()

        #expect(
            command.arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url",
                "--request", "POST",
                "--header", "Accept: application/json",
                "--header", "Content-Type: application/json",
                "--header", "@/run/secrets/api-headers",
                "--data-raw", #"{"name":"sample"}"#,
                "--url", "https://example.com/items",
            ]
        )
    }

    @Test func mapsAllHTTPMethods() {
        let cases: [(CurlHTTPMethod, String)] = [
            (.get, "GET"), (.head, "HEAD"), (.post, "POST"), (.put, "PUT"),
            (.patch, "PATCH"), (.delete, "DELETE"), (.options, "OPTIONS"), (.custom("PROPFIND"), "PROPFIND"),
        ]

        for (method, expected) in cases {
            #expect(
                Curl("https://example.com").method(method).command().arguments == [
                    "--disable", "--no-progress-meter", "--disallow-username-in-url", "--request", expected,
                    "--url", "https://example.com",
                ]
            )
        }
    }

    @Test func bodyModesReplaceEachOther() {
        #expect(
            Curl("https://example.com").bodyFile("payload.bin").command().arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--data-binary", "@payload.bin",
                "--url", "https://example.com",
            ]
        )
        #expect(
            Curl("https://example.com").body("old").uploadFile("archive.zip").command().arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--upload-file", "archive.zip",
                "--url", "https://example.com",
            ]
        )
        #expect(
            Curl("https://example.com").uploadFile("old").body("new").command().arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--data-raw", "new", "--url",
                "https://example.com",
            ]
        )
    }

    @Test func buildsRedirectRetryTimeoutFailureAndOutputOptions() {
        let command = Curl("https://example.com/download")
            .followRedirects()
            .maximumRedirects(4)
            .retry(3)
            .retryDelay(1)
            .retryMaximumTime(12)
            .retryAllErrors()
            .retryConnectionRefused()
            .requestTimeout(30.5)
            .connectionTimeout(2.75)
            .failWithBody()
            .outputFile("response.json")
            .command()

        #expect(
            command.arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--location", "--max-redirs", "4",
                "--retry", "3", "--retry-delay", "1", "--retry-max-time", "12", "--retry-all-errors",
                "--retry-connrefused", "--max-time", "30.5", "--connect-timeout", "2.75",
                "--fail-with-body", "--output", "response.json", "--url", "https://example.com/download",
            ]
        )
    }

    @Test func booleanOptionsCanBeDisabled() {
        let command = Curl("https://example.com")
            .followRedirects().followRedirects(false)
            .retryAllErrors().retryAllErrors(false)
            .retryConnectionRefused().retryConnectionRefused(false)
            .failWithBody().failWithBody(false)
            .command()

        #expect(
            command.arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--url", "https://example.com",
            ]
        )
    }

    @Test func urlAndVersionReplaceTransferMode() {
        #expect(
            Curl().url("https://example.com").command().arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--url", "https://example.com",
            ]
        )
        #expect(Curl("https://example.com").version().command().arguments == ["--disable", "--version"])
    }

    @Test func builderPreservesOriginalValue() {
        let original = Curl("https://example.com")
        let modified = original.method(.delete)

        #expect(
            original.command().arguments == [
                "--disable", "--no-progress-meter", "--disallow-username-in-url", "--url", "https://example.com",
            ]
        )
        #expect(modified.command().arguments.contains("DELETE"))
    }

    @Test func preservesToolAndOutputConfiguration() async throws {
        actor Recorder {
            var command: Command?
            func record(_ command: Command) { self.command = command }
        }

        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)
                return ShellOutput(stdout: "response", stderr: "", exitCode: 0)
            }
        )

        let output = try await Curl("https://example.com", context: context)
            .executable("/usr/local/bin/curl")
            .env("CURL_CA_BUNDLE", "/certs/ca.pem")
            .workingDirectory("/tmp/request")
            .timeout(10)
            .outputLimit(2048)
            .stdout(.tee)
            .stderr(.discard)
            .run()

        let command = await recorder.command
        #expect(output.stdout == "response")
        #expect(command?.executableOverride == "/usr/local/bin/curl")
        #expect(command?.environmentOverrides == ["CURL_CA_BUNDLE": "/certs/ca.pem"])
        #expect(command?.workingDirectoryOverride == "/tmp/request")
        #expect(command?.timeoutOverride == 10)
        #expect(command?.outputLimitOverride == 2048)
        #expect(command?.stdoutDestination == .tee)
        #expect(command?.stderrDestination == .discard)
    }
}
#endif
