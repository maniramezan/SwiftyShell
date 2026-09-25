#if Swift
import Foundation

/// The first argument selected for a ``Swift`` toolchain invocation.
public enum SwiftSubcommand: Sendable, Equatable, Hashable {
    /// `swift --version` — print Swift toolchain version information.
    case version
    /// `swift build` — build a Swift package.
    case build
    /// `swift test` — build and run package tests.
    case test
    /// `swift run` — run an executable product from a package.
    case run
    /// `swift package` — perform Swift Package Manager operations.
    case package
    /// `swift repl` — start the Swift REPL.
    case repl
    /// Any Swift top-level subcommand or flag not modeled by a dedicated case.
    case custom(String)

    fileprivate var argument: String {
        switch self {
        case .version: "--version"
        case .build: "build"
        case .test: "test"
        case .run: "run"
        case .package: "package"
        case .repl: "repl"
        case let .custom(value): value
        }
    }
}

/// A SwiftPM build configuration passed with `--configuration`.
public enum SwiftBuildConfiguration: String, Sendable, Equatable, Hashable {
    /// Debug configuration.
    case debug
    /// Release configuration.
    case release
}

/// A fluent wrapper for the `swift` toolchain command.
///
/// ``Swift`` focuses on common package automation: `swift build`, `swift test`, `swift run`,
/// and `swift package` invocations. It models frequently used SwiftPM options such as package
/// path, build configuration, targets/products, traits, compiler flags, test filters, and code
/// coverage. Use ``argument(_:)`` or ``arguments(_:)`` for plugin commands or newer flags that
/// are not modeled yet.
///
/// ```swift
/// try await Swift(context: context)
///     .build()
///     .configuration(.release)
///     .swiftCompilerFlag("-warnings-as-errors")
///     .run()
/// ```
public struct Swift: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a Swift toolchain command family bound to a shell context.
    ///
    /// The default invocation is `swift --version`, which is safe and read-only. Select package
    /// operations with ``build()``, ``test()``, ``runProduct(_:)``, or ``package(_:)``.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnels the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Swift`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `swift` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. SwiftPM writes package descriptions, version
    /// output, and some command results to stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Swift`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `swift` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. SwiftPM diagnostics and build progress commonly
    /// appear on stderr.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Swift`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that selects a top-level Swift subcommand or flag.
    public func subcommand(_ value: SwiftSubcommand) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.packageSubcommand = nil
        }
    }

    /// Returns a copy that selects a raw top-level Swift subcommand or flag.
    public func subcommand(_ value: String) -> Self { subcommand(.custom(value)) }

    /// Returns a copy that builds the package (`swift build`).
    public func build() -> Self { subcommand(.build) }

    /// Returns a copy that tests the package (`swift test`).
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy that runs an executable package product (`swift run`).
    ///
    /// - Parameter product: Optional executable product name to pass after `swift run` options.
    /// - Returns: A new ``Swift`` value configured for `swift run`.
    public func runProduct(_ product: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = .run
            $0.state.packageSubcommand = nil
            $0.state.positionalArguments = product.map { [$0] } ?? []
        }
    }

    /// Returns a copy that performs a Swift Package Manager operation (`swift package`).
    ///
    /// - Parameter subcommand: Optional package subcommand such as `resolve`, `dump-package`, or
    ///   `show-dependencies`.
    /// - Returns: A new ``Swift`` value configured for `swift package`.
    public func package(_ subcommand: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = .package
            $0.state.packageSubcommand = subcommand
            $0.state.positionalArguments = []
        }
    }

    /// Returns a copy that starts the Swift REPL (`swift repl`).
    public func repl() -> Self { subcommand(.repl) }

    /// Returns a copy that prints toolchain version information (`swift --version`).
    public func version() -> Self { subcommand(.version) }

    /// Returns a copy that sets SwiftPM's package path (`--package-path`).
    public func packagePath(_ path: String) -> Self { modified(self) { $0.state.packagePath = path } }

    /// Returns a copy that sets SwiftPM's scratch path (`--scratch-path`).
    public func scratchPath(_ path: String) -> Self { modified(self) { $0.state.scratchPath = path } }

    /// Returns a copy that selects the package build configuration (`--configuration`).
    public func configuration(_ value: SwiftBuildConfiguration) -> Self {
        modified(self) { $0.state.configuration = value }
    }

    /// Returns a copy that selects a package target (`--target`).
    public func target(_ name: String) -> Self { modified(self) { $0.state.target = name } }

    /// Returns a copy that selects a package product (`--product`).
    public func product(_ name: String) -> Self { modified(self) { $0.state.product = name } }

    /// Returns a copy that sets SwiftPM traits (`--traits`).
    ///
    /// - Parameter names: Trait names to join with commas, matching SwiftPM's expected syntax.
    /// - Returns: A new ``Swift`` value with the trait list applied.
    public func traits(_ names: [String]) -> Self { modified(self) { $0.state.traits = names } }

    /// Returns a copy that sets SwiftPM traits (`--traits`).
    public func traits(_ names: String...) -> Self { traits(names) }

    /// Returns a copy that enables every package trait (`--enable-all-traits`).
    public func enableAllTraits(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.enablesAllTraits = enabled }
    }

    /// Returns a copy that disables default package traits (`--disable-default-traits`).
    public func disableDefaultTraits(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesDefaultTraits = enabled }
    }

    /// Returns a copy that builds package tests during `swift build` (`--build-tests`).
    public func buildTests(_ enabled: Bool = true) -> Self { modified(self) { $0.state.buildsTests = enabled } }

    /// Returns a copy that enables code coverage for supported SwiftPM operations.
    public func codeCoverage(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.enablesCodeCoverage = enabled }
    }

    /// Returns a copy that skips building tests before running them (`--skip-build`).
    public func skipBuild(_ enabled: Bool = true) -> Self { modified(self) { $0.state.skipsBuild = enabled } }

    /// Returns a copy that lists tests instead of running them (`--list-tests`).
    public func listTests(_ enabled: Bool = true) -> Self { modified(self) { $0.state.listsTests = enabled } }

    /// Returns a copy that filters tests by regular expression (`--filter`).
    public func filter(_ pattern: String) -> Self { modified(self) { $0.state.filter = pattern } }

    /// Returns a copy that skips tests matching a regular expression (`--skip`).
    public func skip(_ pattern: String) -> Self { modified(self) { $0.state.skip = pattern } }

    /// Returns a copy that sets the number of build jobs (`--jobs`).
    public func jobs(_ count: Int) -> Self { modified(self) { $0.state.jobs = count } }

    /// Returns a copy that passes a flag through to Swift compiler invocations (`-Xswiftc`).
    public func swiftCompilerFlag(_ value: String) -> Self {
        modified(self) { $0.state.swiftCompilerFlags += [value] }
    }

    /// Returns a copy that passes flags through to Swift compiler invocations (`-Xswiftc`).
    public func swiftCompilerFlags(_ values: [String]) -> Self {
        modified(self) { $0.state.swiftCompilerFlags += values }
    }

    /// Returns a copy that passes a flag through to C compiler invocations (`-Xcc`).
    public func cCompilerFlag(_ value: String) -> Self { modified(self) { $0.state.cCompilerFlags += [value] } }

    /// Returns a copy that passes a flag through to linker invocations (`-Xlinker`).
    public func linkerFlag(_ value: String) -> Self { modified(self) { $0.state.linkerFlags += [value] } }

    /// Returns a copy that appends a raw argument before positional arguments.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw arguments before positional arguments.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends a positional argument after modeled and raw options.
    public func positionalArgument(_ value: String) -> Self {
        modified(self) { $0.state.positionalArguments += [value] }
    }

    /// Returns a copy that appends positional arguments after modeled and raw options.
    public func positionalArguments(_ values: [String]) -> Self {
        modified(self) { $0.state.positionalArguments += values }
    }

    /// Builds the raw `swift` command represented by the current builder state.
    ///
    /// Arguments are emitted deterministically as subcommand, package subcommand, modeled options,
    /// raw arguments, then positional arguments.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = [state.subcommand.argument]

        if let packageSubcommand = state.packageSubcommand {
            arguments.append(packageSubcommand)
        }

        if let packagePath = state.packagePath {
            arguments.append("--package-path")
            arguments.append(packagePath)
        }

        if let scratchPath = state.scratchPath {
            arguments.append("--scratch-path")
            arguments.append(scratchPath)
        }

        if let configuration = state.configuration {
            arguments.append("--configuration")
            arguments.append(configuration.rawValue)
        }

        if let target = state.target {
            arguments.append("--target")
            arguments.append(target)
        }

        if let product = state.product {
            arguments.append("--product")
            arguments.append(product)
        }

        if !state.traits.isEmpty {
            arguments.append("--traits")
            arguments.append(state.traits.joined(separator: ","))
        }

        if state.enablesAllTraits { arguments.append("--enable-all-traits") }
        if state.disablesDefaultTraits { arguments.append("--disable-default-traits") }
        if state.buildsTests { arguments.append("--build-tests") }
        if state.enablesCodeCoverage { arguments.append("--enable-code-coverage") }
        if state.skipsBuild { arguments.append("--skip-build") }
        if state.listsTests { arguments.append("--list-tests") }

        if let filter = state.filter {
            arguments.append("--filter")
            arguments.append(filter)
        }

        if let skip = state.skip {
            arguments.append("--skip")
            arguments.append(skip)
        }

        if let jobs = state.jobs {
            arguments.append("--jobs")
            arguments.append(String(jobs))
        }

        for flag in state.swiftCompilerFlags {
            arguments.append("-Xswiftc")
            arguments.append(flag)
        }

        for flag in state.cCompilerFlags {
            arguments.append("-Xcc")
            arguments.append(flag)
        }

        for flag in state.linkerFlags {
            arguments.append("-Xlinker")
            arguments.append(flag)
        }

        arguments.append(contentsOf: state.extraArguments)
        arguments.append(contentsOf: state.positionalArguments)

        let base = Command("swift")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var subcommand: SwiftSubcommand = .version
    var packageSubcommand: String? = nil
    var packagePath: String? = nil
    var scratchPath: String? = nil
    var configuration: SwiftBuildConfiguration? = nil
    var target: String? = nil
    var product: String? = nil
    var traits: [String] = []
    var enablesAllTraits: Bool = false
    var disablesDefaultTraits: Bool = false
    var buildsTests: Bool = false
    var enablesCodeCoverage: Bool = false
    var skipsBuild: Bool = false
    var listsTests: Bool = false
    var filter: String? = nil
    var skip: String? = nil
    var jobs: Int? = nil
    var swiftCompilerFlags: [String] = []
    var cCompilerFlags: [String] = []
    var linkerFlags: [String] = []
    var extraArguments: [String] = []
    var positionalArguments: [String] = []
}
#endif
