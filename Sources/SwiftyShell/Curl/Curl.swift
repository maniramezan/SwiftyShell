#if Curl
import Foundation

/// An HTTP request method used by ``Curl``.
public enum CurlHTTPMethod: Sendable, Equatable, Hashable {
    /// The `GET` method.
    case get
    /// The `HEAD` method.
    case head
    /// The `POST` method.
    case post
    /// The `PUT` method.
    case put
    /// The `PATCH` method.
    case patch
    /// The `DELETE` method.
    case delete
    /// The `OPTIONS` method.
    case options
    /// A method not represented by a predefined case.
    case custom(String)

    fileprivate var argument: String {
        switch self {
        case .get: "GET"
        case .head: "HEAD"
        case .post: "POST"
        case .put: "PUT"
        case .patch: "PATCH"
        case .delete: "DELETE"
        case .options: "OPTIONS"
        case .custom(let value): value
        }
    }
}

/// A focused, fluent wrapper for HTTP transfers with curl.
///
/// ``Curl`` models one request per value for command-line automation. Prefer `URLSession` or a
/// dedicated HTTP client for ordinary in-process Swift API calls. Use ``Curl`` when you need curl's
/// CLI behavior: pipeline composition, CI script parity, artifact transfer, vendor recipe
/// reproduction, or curl-specific transfer options.
///
/// The builder disables curl's implicit configuration file so invocation behavior comes only from
/// the builder. Header and body strings become process arguments; use ``headerFile(_:)`` and
/// ``bodyFile(_:)`` for sensitive or large content.
///
/// ```swift
/// let output = try await Curl("https://api.example.com/items", context: context)
///     .method(.post)
///     .header(name: "Content-Type", value: "application/json")
///     .body(#"{"name":"example"}"#)
///     .failWithBody()
///     .run()
/// ```
public struct Curl: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a curl command family bound to a shell context.
    ///
    /// The default invocation prints curl version information. Call ``url(_:)`` to build a
    /// transfer instead.
    ///
    /// - Parameter context: The context used to execute the command.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    /// Creates a curl request for a URL.
    ///
    /// - Parameters:
    ///   - url: The URL curl should transfer.
    ///   - context: The context used to execute the command.
    public init(_ url: String, context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context), url: url)
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes curl's stdout to a destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes curl's stderr to a destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that prints curl version information instead of performing a transfer.
    public func version() -> Self { modified(self) { $0.state.url = nil } }

    /// Returns a copy that transfers the given URL.
    public func url(_ value: String) -> Self { modified(self) { $0.state.url = value } }

    /// Returns a copy that uses an explicit HTTP request method.
    public func method(_ value: CurlHTTPMethod) -> Self { modified(self) { $0.state.method = value } }

    /// Returns a copy with an additional request header.
    ///
    /// The complete header is placed in the process argument list and may be visible to local
    /// process inspection. Do not pass credentials here; put sensitive headers in a
    /// permission-restricted file and use ``headerFile(_:)``.
    public func header(name: String, value: String) -> Self {
        modified(self) { $0.state.headers += ["\(name): \(value)"] }
    }

    /// Returns a copy that reads additional request headers from a file.
    ///
    /// curl receives only the file path in argv. Protect the file with appropriate permissions
    /// and avoid logging its contents.
    public func headerFile(_ path: String) -> Self { modified(self) { $0.state.headerFiles += [path] } }

    /// Returns a copy that sends text as request data using `--data-raw`.
    ///
    /// The value is placed in argv and should not contain credentials or other secrets. This
    /// replaces any previously configured body or upload file.
    public func body(_ value: String) -> Self { modified(self) { $0.state.payload = .body(value) } }

    /// Returns a copy that reads the request body from a file without text conversion.
    ///
    /// This maps to `--data-binary @<path>` and replaces any previously configured body or
    /// upload file.
    public func bodyFile(_ path: String) -> Self { modified(self) { $0.state.payload = .bodyFile(path) } }

    /// Returns a copy that uploads a file using curl's `--upload-file` transfer mode.
    ///
    /// This replaces any previously configured request body or upload file.
    public func uploadFile(_ path: String) -> Self { modified(self) { $0.state.payload = .uploadFile(path) } }

    /// Returns a copy that follows HTTP redirects.
    public func followRedirects(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.followsRedirects = enabled }
    }

    /// Returns a copy with the maximum number of redirects curl may follow.
    ///
    /// This setting does not enable redirects by itself; combine it with ``followRedirects(_:)``.
    public func maximumRedirects(_ count: Int) -> Self { modified(self) { $0.state.maximumRedirects = count } }

    /// Returns a copy that retries transient failures up to the given count.
    public func retry(_ count: Int) -> Self { modified(self) { $0.state.retryCount = count } }

    /// Returns a copy with a fixed delay in seconds between retries.
    public func retryDelay(_ seconds: Int) -> Self { modified(self) { $0.state.retryDelay = seconds } }

    /// Returns a copy with a total time limit in seconds for retries.
    public func retryMaximumTime(_ seconds: Int) -> Self { modified(self) { $0.state.retryMaximumTime = seconds } }

    /// Returns a copy that retries all curl errors considered retry-safe by the caller.
    public func retryAllErrors(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.retriesAllErrors = enabled }
    }

    /// Returns a copy that treats connection-refused failures as transient for retry purposes.
    public func retryConnectionRefused(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.retriesConnectionRefused = enabled }
    }

    /// Returns a copy with curl's maximum transfer duration in seconds.
    ///
    /// Unlike inherited ``timeout(_:)-(Duration)``, which controls the subprocess executor, this maps to
    /// curl's `--max-time` transfer timer.
    public func requestTimeout(_ seconds: TimeInterval) -> Self { modified(self) { $0.state.requestTimeout = seconds } }

    /// Returns a copy with curl's connection-phase timeout in seconds.
    public func connectionTimeout(_ seconds: TimeInterval) -> Self {
        modified(self) { $0.state.connectionTimeout = seconds }
    }

    /// Returns a copy that makes HTTP status codes 400 and above fail while retaining the body.
    public func failWithBody(_ enabled: Bool = true) -> Self { modified(self) { $0.state.failsWithBody = enabled } }

    /// Returns a copy that asks curl to write the response body to a file.
    ///
    /// This maps to curl's `--output`; inherited ``stdout(_:)`` controls process-level stdout
    /// routing instead.
    public func outputFile(_ path: String) -> Self { modified(self) { $0.state.outputFile = path } }

    /// Builds the raw curl command represented by the current builder state.
    public func command() -> Command {
        var arguments = ["--disable"]

        guard let url = state.url else {
            return configuredCommand(arguments + ["--version"])
        }

        arguments += ["--no-progress-meter", "--disallow-username-in-url"]
        if let method = state.method { arguments += ["--request", method.argument] }
        for header in state.headers { arguments += ["--header", header] }
        for path in state.headerFiles { arguments += ["--header", "@\(path)"] }

        switch state.payload {
        case .body(let value): arguments += ["--data-raw", value]
        case .bodyFile(let path): arguments += ["--data-binary", "@\(path)"]
        case .uploadFile(let path): arguments += ["--upload-file", path]
        case nil: break
        }

        if state.followsRedirects { arguments.append("--location") }
        appendOption("--max-redirs", state.maximumRedirects.map(String.init), to: &arguments)
        appendOption("--retry", state.retryCount.map(String.init), to: &arguments)
        appendOption("--retry-delay", state.retryDelay.map(String.init), to: &arguments)
        appendOption("--retry-max-time", state.retryMaximumTime.map(String.init), to: &arguments)
        if state.retriesAllErrors { arguments.append("--retry-all-errors") }
        if state.retriesConnectionRefused { arguments.append("--retry-connrefused") }
        appendOption("--max-time", state.requestTimeout.map(formatSeconds), to: &arguments)
        appendOption("--connect-timeout", state.connectionTimeout.map(formatSeconds), to: &arguments)
        if state.failsWithBody { arguments.append("--fail-with-body") }
        appendOption("--output", state.outputFile, to: &arguments)
        arguments += ["--url", url]
        return configuredCommand(arguments)
    }

    private func configuredCommand(_ arguments: [String]) -> Command {
        state.config.apply(
            to: Command("curl")
                .args(arguments)
                .stdout(state.stdoutDestination)
                .stderr(state.stderrDestination)
        )
    }

    private func formatSeconds(_ seconds: TimeInterval) -> String {
        String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), seconds)
    }
}

private enum Payload: Sendable {
    case body(String)
    case bodyFile(String)
    case uploadFile(String)
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var url: String? = nil
    var method: CurlHTTPMethod? = nil
    var headers: [String] = []
    var headerFiles: [String] = []
    var payload: Payload? = nil
    var followsRedirects: Bool = false
    var maximumRedirects: Int? = nil
    var retryCount: Int? = nil
    var retryDelay: Int? = nil
    var retryMaximumTime: Int? = nil
    var retriesAllErrors: Bool = false
    var retriesConnectionRefused: Bool = false
    var requestTimeout: TimeInterval? = nil
    var connectionTimeout: TimeInterval? = nil
    var failsWithBody: Bool = false
    var outputFile: String? = nil
}
#endif
