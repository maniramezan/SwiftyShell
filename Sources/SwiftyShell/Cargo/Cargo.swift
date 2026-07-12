#if Cargo
/// A supported Cargo operation.
public enum CargoSubcommand: Sendable, Equatable, Hashable {
    /// `cargo --version` prints Cargo version information.
    case version
    /// `cargo build` compiles a package.
    case build
    /// `cargo test` compiles and runs tests.
    case test
    /// `cargo check` checks a package without producing final artifacts.
    case check
    /// `cargo run` compiles and runs a binary or example.
    case run
    /// `cargo fmt` formats Rust source with rustfmt.
    case format
    /// `cargo clippy` checks Rust source with Clippy.
    case clippy
    /// `cargo package` assembles a distributable package.
    case package
    /// A Cargo subcommand or top-level flag not modeled by a dedicated case.
    case custom(String)

    fileprivate var argument: String {
        switch self {
        case .version: "--version"
        case .build: "build"
        case .test: "test"
        case .check: "check"
        case .run: "run"
        case .format: "fmt"
        case .clippy: "clippy"
        case .package: "package"
        case let .custom(value): value
        }
    }
}

/// A Cargo target kind selected by a fluent target method.
public enum CargoTarget: Sendable, Equatable, Hashable {
    /// The package library target (`--lib`).
    case library
    /// A named binary target (`--bin <name>`).
    case binary(String)
    /// Every binary target (`--bins`).
    case binaries
    /// A named example target (`--example <name>`).
    case example(String)
    /// Every example target (`--examples`).
    case examples
    /// A named integration-test target (`--test <name>`).
    case test(String)
    /// Every test target (`--tests`).
    case tests
    /// A named benchmark target (`--bench <name>`).
    case benchmark(String)
    /// Every benchmark target (`--benches`).
    case benchmarks
    /// Every supported target (`--all-targets`).
    case all

    fileprivate var arguments: [String] {
        switch self {
        case .library: ["--lib"]
        case let .binary(name): ["--bin", name]
        case .binaries: ["--bins"]
        case let .example(name): ["--example", name]
        case .examples: ["--examples"]
        case let .test(name): ["--test", name]
        case .tests: ["--tests"]
        case let .benchmark(name): ["--bench", name]
        case .benchmarks: ["--benches"]
        case .all: ["--all-targets"]
        }
    }
}

/// A fluent wrapper for the Cargo package manager and build tool.
///
/// ``Cargo`` models common build, test, check, run, format, Clippy, and package
/// operations. Arguments for programs, test harnesses, rustfmt, and Clippy are
/// emitted after Cargo's required `--` separator.
///
/// ```swift
/// try await Cargo()
///     .test()
///     .workspace()
///     .allFeatures()
///     .testArguments(["--nocapture"])
///     .run()
/// ```
public struct Cargo: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Cargo command family bound to a shell context.
    ///
    /// The default command is the safe, read-only `cargo --version`.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects a Cargo operation.
    public func subcommand(_ value: CargoSubcommand) -> Self {
        copy(subcommand: value, testFilter: .some(nil), forwardedArguments: [])
    }

    /// Returns a copy that selects a raw Cargo operation.
    public func subcommand(_ value: String) -> Self { subcommand(.custom(value)) }

    /// Returns a copy configured for `cargo build`.
    public func build() -> Self { subcommand(.build) }

    /// Returns a copy configured for `cargo test`.
    ///
    /// - Parameter filter: An optional test-name filter emitted before the `--`
    ///   test-harness argument boundary.
    public func test(_ filter: String? = nil) -> Self {
        copy(subcommand: .test, testFilter: .some(filter), forwardedArguments: [])
    }

    /// Returns a copy configured for `cargo check`.
    public func check() -> Self { subcommand(.check) }

    /// Returns a copy configured for `cargo run`.
    ///
    /// - Parameter binary: An optional binary target selected with `--bin`.
    public func runBinary(_ binary: String? = nil) -> Self {
        copy(
            subcommand: .run,
            targets: binary.map { [.binary($0)] } ?? [],
            testFilter: .some(nil),
            forwardedArguments: []
        )
    }

    /// Returns a copy configured for `cargo fmt`.
    public func format() -> Self { subcommand(.format) }

    /// Returns a copy configured for `cargo clippy`.
    public func clippy() -> Self { subcommand(.clippy) }

    /// Returns a copy configured for `cargo package`.
    public func package() -> Self { subcommand(.package) }

    /// Returns a copy that prints Cargo version information.
    public func version() -> Self { subcommand(.version) }

    /// Returns a copy that uses a specific `Cargo.toml` file (`--manifest-path`).
    public func manifestPath(_ path: String) -> Self { copy(manifestPath: path) }

    /// Returns a copy that selects a package (`--package`).
    public func package(_ name: String) -> Self { copy(packages: state.packages + [name]) }

    /// Returns a copy that selects packages (`--package` for each value).
    public func packages(_ names: [String]) -> Self { copy(packages: state.packages + names) }

    /// Returns a copy that selects the workspace.
    ///
    /// This emits `--workspace` for Cargo operations and `--all` for `cargo fmt`,
    /// matching cargo-fmt's current workspace spelling.
    public func workspace(_ enabled: Bool = true) -> Self { copy(workspaceEnabled: enabled) }

    /// Returns a copy that activates Cargo features (`--features`).
    public func features(_ names: [String]) -> Self { copy(features: names) }

    /// Returns a copy that activates Cargo features (`--features`).
    public func features(_ names: String...) -> Self { features(names) }

    /// Returns a copy that activates every feature (`--all-features`).
    public func allFeatures(_ enabled: Bool = true) -> Self { copy(allFeaturesEnabled: enabled) }

    /// Returns a copy that disables default features (`--no-default-features`).
    public func noDefaultFeatures(_ enabled: Bool = true) -> Self { copy(noDefaultFeaturesEnabled: enabled) }

    /// Returns a copy that adds a target selection.
    public func target(_ value: CargoTarget) -> Self { copy(targets: state.targets + [value]) }

    /// Returns a copy that selects the library target (`--lib`).
    public func library() -> Self { target(.library) }

    /// Returns a copy that selects a binary target (`--bin`).
    public func binary(_ name: String) -> Self { target(.binary(name)) }

    /// Returns a copy that selects every binary target (`--bins`).
    public func binaries() -> Self { target(.binaries) }

    /// Returns a copy that selects an example target (`--example`).
    public func example(_ name: String) -> Self { target(.example(name)) }

    /// Returns a copy that selects every example target (`--examples`).
    public func examples() -> Self { target(.examples) }

    /// Returns a copy that selects an integration-test target (`--test`).
    public func testTarget(_ name: String) -> Self { target(.test(name)) }

    /// Returns a copy that selects every test target (`--tests`).
    public func testTargets() -> Self { target(.tests) }

    /// Returns a copy that selects a benchmark target (`--bench`).
    public func benchmark(_ name: String) -> Self { target(.benchmark(name)) }

    /// Returns a copy that selects every benchmark target (`--benches`).
    public func benchmarks() -> Self { target(.benchmarks) }

    /// Returns a copy that selects all targets (`--all-targets`).
    public func allTargets() -> Self { target(.all) }

    /// Returns a copy that requests optimized artifacts (`--release`).
    public func release(_ enabled: Bool = true) -> Self { copy(releaseEnabled: enabled) }

    /// Returns a copy that appends a raw Cargo argument before target and forwarded arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw Cargo arguments before target and forwarded arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends an argument for the program selected by `cargo run`.
    ///
    /// ``command()`` inserts `--` before program arguments.
    public func programArgument(_ value: String) -> Self {
        copy(forwardedArguments: state.forwardedArguments + [value])
    }

    /// Returns a copy that appends arguments for the program selected by `cargo run`.
    ///
    /// ``command()`` inserts `--` before program arguments.
    public func programArguments(_ values: [String]) -> Self {
        copy(forwardedArguments: state.forwardedArguments + values)
    }

    /// Returns a copy that appends an argument for the `cargo test` harness.
    ///
    /// ``command()`` inserts `--` before test-harness arguments.
    public func testArgument(_ value: String) -> Self { programArgument(value) }

    /// Returns a copy that appends arguments for the `cargo test` harness.
    ///
    /// ``command()`` inserts `--` before test-harness arguments.
    public func testArguments(_ values: [String]) -> Self { programArguments(values) }

    /// Returns a copy that appends an argument forwarded to rustfmt or Clippy.
    ///
    /// ``command()`` inserts `--` before tool arguments.
    public func toolArgument(_ value: String) -> Self { programArgument(value) }

    /// Returns a copy that appends arguments forwarded to rustfmt or Clippy.
    ///
    /// ``command()`` inserts `--` before tool arguments.
    public func toolArguments(_ values: [String]) -> Self { programArguments(values) }

    /// Builds the raw `cargo` command represented by the current builder state.
    public func command() -> Command {
        var arguments = [state.subcommand.argument]

        if let manifestPath = state.manifestPath {
            arguments += ["--manifest-path", manifestPath]
        }
        for package in state.packages { arguments += ["--package", package] }
        if state.workspaceEnabled {
            arguments.append(state.subcommand == .format ? "--all" : "--workspace")
        }
        if !state.features.isEmpty { arguments += ["--features", state.features.joined(separator: ",")] }
        if state.allFeaturesEnabled { arguments.append("--all-features") }
        if state.noDefaultFeaturesEnabled { arguments.append("--no-default-features") }
        for target in state.targets { arguments += target.arguments }
        if state.releaseEnabled { arguments.append("--release") }
        arguments += state.extraArguments
        if let testFilter = state.testFilter { arguments.append(testFilter) }
        if !state.forwardedArguments.isEmpty { arguments += ["--"] + state.forwardedArguments }

        let base = Command("cargo")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: CargoSubcommand? = nil,
        manifestPath: String?? = nil,
        packages: [String]? = nil,
        workspaceEnabled: Bool? = nil,
        features: [String]? = nil,
        allFeaturesEnabled: Bool? = nil,
        noDefaultFeaturesEnabled: Bool? = nil,
        targets: [CargoTarget]? = nil,
        releaseEnabled: Bool? = nil,
        testFilter: String?? = nil,
        extraArguments: [String]? = nil,
        forwardedArguments: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                manifestPath: manifestPath ?? state.manifestPath,
                packages: packages ?? state.packages,
                workspaceEnabled: workspaceEnabled ?? state.workspaceEnabled,
                features: features ?? state.features,
                allFeaturesEnabled: allFeaturesEnabled ?? state.allFeaturesEnabled,
                noDefaultFeaturesEnabled: noDefaultFeaturesEnabled ?? state.noDefaultFeaturesEnabled,
                targets: targets ?? state.targets,
                releaseEnabled: releaseEnabled ?? state.releaseEnabled,
                testFilter: testFilter ?? state.testFilter,
                extraArguments: extraArguments ?? state.extraArguments,
                forwardedArguments: forwardedArguments ?? state.forwardedArguments
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let subcommand: CargoSubcommand
    let manifestPath: String?
    let packages: [String]
    let workspaceEnabled: Bool
    let features: [String]
    let allFeaturesEnabled: Bool
    let noDefaultFeaturesEnabled: Bool
    let targets: [CargoTarget]
    let releaseEnabled: Bool
    let testFilter: String?
    let extraArguments: [String]
    let forwardedArguments: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: CargoSubcommand = .version,
        manifestPath: String? = nil,
        packages: [String] = [],
        workspaceEnabled: Bool = false,
        features: [String] = [],
        allFeaturesEnabled: Bool = false,
        noDefaultFeaturesEnabled: Bool = false,
        targets: [CargoTarget] = [],
        releaseEnabled: Bool = false,
        testFilter: String? = nil,
        extraArguments: [String] = [],
        forwardedArguments: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.manifestPath = manifestPath
        self.packages = packages
        self.workspaceEnabled = workspaceEnabled
        self.features = features
        self.allFeaturesEnabled = allFeaturesEnabled
        self.noDefaultFeaturesEnabled = noDefaultFeaturesEnabled
        self.targets = targets
        self.releaseEnabled = releaseEnabled
        self.testFilter = testFilter
        self.extraArguments = extraArguments
        self.forwardedArguments = forwardedArguments
    }
}
#endif
