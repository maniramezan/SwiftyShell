# SwiftyShell Skill

This public file is maintainer-oriented automation guidance for repository assistants. It is optional for human contributors and should only be updated when the documented public API or shared agent workflow changes.

This skill serves two purposes:

1. **Code generation** — generate correct, strongly-typed SwiftyShell code from plain-language task descriptions
2. **Contribution guidance** — add new command families following established conventions

---

## Part 1: Generating SwiftyShell Code

### Type Selection Rules

Before writing any code, follow this decision tree:

1. Is this a git operation supported by the typed `Git` API (`status()`, `pull()`, `fetch()`, `branch()`, `stash()`, `worktree()`, `submodule()`, `diff()`, `log()`, `gitConfig()`, `merge()`, `commit()`, `rebase()`)?
   → Use `Git`
2. Is this a git operation NOT covered by the typed `Git` API?
   → Use `Command("git", arguments: ...)`
3. Is this a file-system operation covered by a typed wrapper (`Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Rsync`)?
   → Use the typed wrapper
4. Is this an archive operation (`tar`, `zip`, or `unzip`)?
   → Use `Tar`, `Zip`, or `Unzip`
5. Is this a `grep` or `jq` operation?
   → Use `Grep` or `Jq`
6. Is this a Homebrew operation (`brew install`, `brew upgrade`, `brew list`, ...)?
   → Use `Brew`
7. Is this a Swift toolchain or SwiftPM operation (`swift build`, `swift test`, `swift run`, `swift package`, ...)?
   → Use `Swift`
8. Is this a GitHub CLI operation (`gh pr`, `gh repo`, `gh workflow`, `gh api`, `gh copilot`, `gh skill`, ...)?
   → Use `Gh`
9. Is this a Docker CLI operation (`docker buildx`, `docker compose`, `docker debug`, `docker mcp`, `docker scout`, ...)?
   → Use `Docker`
10. Is this a Makefile operation (`make check`, `make test`, `make -j8`, ...)?
    → Use `Make`
11. Is this a Node.js runtime operation (`node --eval`, `node --check`, running a `.js` file, ...)?
    → Use `Node`
12. Is this an npm operation (`npm ci`, `npm run build`, `npm exec`, ...)?
    → Use `Npm`
13. Is this a Yarn operation (`yarn install`, `yarn run build`, `yarn dlx`, ...)?
    → Use `Yarn`
14. Is this a pnpm operation (`pnpm install`, `pnpm run build`, `pnpm exec`, ...)?
    → Use `Pnpm`
15. Is this a Bun operation (`bun run`, `bun test`, `bun build`, ...)?
    → Use `Bun`
16. Is this a Terraform operation (`terraform init`, `terraform plan`, `terraform apply`, ...)?
    → Use `Terraform`
17. Is this a Kubernetes CLI operation (`kubectl get`, `kubectl apply`, `kubectl logs`, ...)?
    → Use `Kubectl`
18. Is this a Helm operation (`helm template`, `helm lint`, `helm upgrade`, ...)?
    → Use `Helm` and its operation-specific builder
19. Is this a Python interpreter operation (`python3 -m`, `python3 -c`, running a `.py` file, ...)?
    → Use `Python`
20. Does the operation need typed output, structured results, or conditional follow-up?
    → Use the appropriate typed client
21. Are two or more commands chained by pipe?
    → Use `.pipe(to:)` to build a `Pipeline`
22. Does the command write output to a file?
    → Use `.stdout(.file(path:append:))` on the command
23. Is this any other command?
       → Use `Command`

### API Reference

#### ShellContext

```swift
public enum ShellPlatform: Sendable {
    case macOS
    case linux

    public static let current: ShellPlatform
    public var defaultSearchPaths: [String] { get }
}

public struct ShellContext: Sendable {
    public static let defaultSearchPaths: [String]

    public static func defaultSearchPaths(
        environment: [String: String],
        platform: ShellPlatform = .current
    ) -> [String]

    public init(
        executor: any CommandExecutor = SubprocessExecutor(),
        searchPaths: [String] = ShellContext.defaultSearchPaths,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        workingDirectory: String? = nil,
        defaultTimeout: TimeInterval? = nil,
        defaultOutputLimit: Int = 0
    )

    public let executor: any CommandExecutor
    public let searchPaths: [String]
    public let environment: [String: String]
    public let workingDirectory: String?
    public let defaultTimeout: TimeInterval?
    public let defaultOutputLimit: Int
}
```

#### Command

```swift
public struct Command: Sendable {
    public init(_ executable: String, arguments: String...)

    public func executable(_ path: String) -> Self
    public func arg(_ value: String) -> Self
    public func args(_ values: [String]) -> Self
    public func env(_ name: String, _ value: String) -> Self
    public func env(_ values: [String: String]) -> Self
    public func workingDirectory(_ path: String) -> Self
    public func timeout(_ seconds: TimeInterval) -> Self
    public func outputLimit(_ bytes: Int) -> Self
    public func stdout(_ destination: OutputDestination) -> Self
    public func stderr(_ destination: OutputDestination) -> Self
    public func pipe(to next: Command) -> Pipeline

    public func run(in context: ShellContext = .init()) async throws -> ShellOutput
    public func spawn(
        in context: ShellContext = .init(),
        teardown: TeardownStrategy = .graceful
    ) async throws -> any SpawnedProcess
}
```

#### Pipeline

```swift
public struct Pipeline: Sendable {
    public let stages: [Command]

    public func pipe(to next: Command) -> Self
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput
}
```

#### Spawned Processes

```swift
public protocol SpawnedProcess: Sendable {
    var processIdentifier: Int32 { get }
    var standardOutput: AsyncStream<String> { get }
    var standardError: AsyncStream<String> { get }

    func send(_ signal: ProcessSignal) async throws
    func interrupt() async throws
    func terminate() async throws
    func teardownAndWait() async -> ShellOutput
    func waitForExit() async -> ShellOutput
}

public enum ProcessSignal: Int32, Sendable, Hashable {
    case interrupt = 2
    case terminate = 15
    case kill = 9
    case hangup = 1
    case quit = 3
}

public struct ProcessTeardownStep: Sendable, Hashable {
    public let signal: ProcessSignal
    public let gracePeriod: Duration

    public init(signal: ProcessSignal, gracePeriod: Duration)
}

public struct TeardownStrategy: Sendable, Hashable {
    public let steps: [ProcessTeardownStep]

    public init(steps: [ProcessTeardownStep])

    public static let graceful: TeardownStrategy
    public static let interruptThenTerminate: TeardownStrategy
    public static let immediate: TeardownStrategy
}
```

#### Executor and Runnable Helpers

```swift
public protocol CommandExecutor: Sendable {
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput
    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
    func spawn(
        _ command: Command,
        in context: ShellContext,
        teardown: TeardownStrategy
    ) async throws -> any SpawnedProcess
}

public protocol RunnableCommandFamily: OutputRedirectingCommandFamily {
    func command() -> Command
}

public extension RunnableCommandFamily {
    func run() async throws -> ShellOutput
    func spawn(teardown: TeardownStrategy = .graceful) async throws -> any SpawnedProcess
}
```

#### OutputDestination

```swift
public enum OutputDestination: Sendable, Equatable {
    case capture
    case discard
    case file(path: String, append: Bool)
    case tee  // streams live to the parent stdout/stderr AND captures into ShellOutput
}
```

#### ShellOutput

```swift
public struct ShellOutput: Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32
    public var isSuccess: Bool
}
```

#### ShellError

```swift
public enum ShellError: Error, LocalizedError {
    case invalidConfiguration(description: String)
    case commandNotFound(String)
    case exitFailure(command: String, output: ShellOutput)
    case timeout(command: String, duration: TimeInterval, partialOutput: ShellOutput)
    case decodingError(command: String, stream: StreamKind)
    case outputLimitExceeded(command: String, limit: Int, partialOutput: ShellOutput)
    case canceled(command: String, partialOutput: ShellOutput)
    case spawnError(command: String, reason: String)
    case workflowConditionFailed(description: String)
}

public enum StreamKind: Sendable {
    case stdout
    case stderr
}
```

#### Workflow\<Value\>

```swift
public struct Workflow<Value>: Sendable {
    public consuming func run() async throws -> Value

    public func map<T>(_ transform: @escaping @Sendable (Value) throws -> T) -> Workflow<T>
    public func map<T>(_ keyPath: KeyPath<Value, T>) -> Workflow<T>

    public func require(
        _ predicate: @escaping @Sendable (Value) throws -> Bool,
        else error: @autoclosure @escaping @Sendable () -> Error
    ) -> Workflow<Value>

    public func require<T: Equatable>(
        _ keyPath: KeyPath<Value, T>,
        equals expected: T,
        else error: @autoclosure @escaping @Sendable () -> Error
    ) -> Workflow<Value>
}
```

`run()` is `consuming`, but workflows are copyable values that retain reusable closures. Each run starts the described operation again; avoid repetition or concurrency when the underlying operation makes it unsafe.

#### Git / GitStatusWorkflow

```swift
public struct Git: Sendable {
    public init(context: ShellContext = .init())

    public func executable(_ path: String) -> Self
    public func env(_ name: String, _ value: String) -> Self
    public func env(_ values: [String: String]) -> Self
    public func workingDirectory(_ path: String) -> Self
    public func timeout(_ seconds: TimeInterval) -> Self
    public func outputLimit(_ bytes: Int) -> Self

    public func status() -> GitStatusWorkflow
    public func branch() -> GitBranch
    public func stash() -> GitStash
    public func worktree() -> GitWorktree
    public func submodule() -> GitSubmodule
    public func diff() -> GitDiff
    public func log() -> GitLog
    public func gitConfig() -> GitConfigCommand
    public func configuration() -> GitConfigCommand
    public func merge() -> GitMerge
    public func commit() -> GitCommit
    public func rebase() -> GitRebase
    public func pull() -> Workflow<GitPullResult>
    public func fetch() -> Workflow<GitFetchResult>
}

public struct GitStatusWorkflow: Sendable {
    public consuming func run() async throws -> GitStatus

    public func map<T>(_ transform: @escaping @Sendable (GitStatus) throws -> T) -> Workflow<T>
    public func map<T>(_ keyPath: KeyPath<GitStatus, T>) -> Workflow<T>

    public func require(
        _ predicate: @escaping @Sendable (GitStatus) throws -> Bool,
        else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(description: "Git workflow condition failed")
    ) -> GitStatusWorkflow

    public func require<T: Equatable>(
        _ keyPath: KeyPath<GitStatus, T>,
        equals expected: T,
        else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(description: "Git workflow condition failed")
    ) -> GitStatusWorkflow

    public func pull() -> Workflow<GitPullResult>
    public func fetch() -> Workflow<GitFetchResult>
}

public struct GitStatus: Sendable {
    public var state: GitWorkingTreeState
    public var branch: String?
    public var upstream: String?
    public var hasStagedChanges: Bool
    public var hasUnstagedChanges: Bool
    public var hasUntrackedFiles: Bool
}

public enum GitWorkingTreeState: Sendable {
    case noChanges
    case dirty
}

public struct GitPullResult: Sendable {
    public var branch: String
    public var upstream: String?
}

public struct GitFetchResult: Sendable {
    public var remote: String
}

public enum GitDiffFormat: Sendable, Equatable, Hashable {
    case patch
    case stat
    case nameOnly
    case nameStatus
}

public enum GitLogFormat: Sendable, Equatable, Hashable {
    case medium
    case oneline
    case short
    case pretty(String)
}

public enum GitConfigFormat: Sendable, Equatable, Hashable {
    case defaultFormat
    case nullTerminated
    case showOrigin
    case showScope
}

public struct GitBranch: RunnableCommandFamily {
    public func list(_ enabled: Bool = true) -> Self
    public func all(_ enabled: Bool = true) -> Self
    public func delete(_ name: String) -> Self
    public func forceDelete(_ name: String) -> Self
    public func named(_ name: String) -> Self
    public func startPoint(_ value: String) -> Self
    public func move(to newName: String) -> Self
    public func entries() -> Workflow<[GitBranchEntry]>
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitStash: RunnableCommandFamily {
    public func push() -> Self
    public func pop() -> Self
    public func apply() -> Self
    public func list() -> Self
    public func show() -> Self
    public func drop() -> Self
    public func delete() -> Self
    public func clear() -> Self
    public func branch(_ name: String) -> Self
    public func create() -> Self
    public func includeUntracked(_ enabled: Bool = true) -> Self
    public func message(_ value: String) -> Self
    public func reference(_ value: String) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitWorktree: RunnableCommandFamily {
    public func list() -> Self
    public func add(_ path: String) -> Self
    public func remove(_ path: String) -> Self
    public func branch(_ value: String) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum GitSubmoduleUpdateStrategy: Sendable, Equatable, Hashable {
    case checkout
    case rebase
    case merge
}

public struct GitSubmodule: RunnableCommandFamily {
    public func add(_ repository: String, path: String? = nil) -> Self
    public func status() -> Self
    public func initialize() -> Self
    public func deinitialize() -> Self
    public func update() -> Self
    public func setBranch(_ branch: String, path: String) -> Self
    public func resetBranch(path: String) -> Self
    public func setUrl(path: String, to newURL: String) -> Self
    public func summary() -> Self
    public func foreach(_ command: String) -> Self
    public func sync() -> Self
    public func absorbGitDirectories() -> Self
    public func quiet(_ enabled: Bool = true) -> Self
    public func cached(_ enabled: Bool = true) -> Self
    public func recursive(_ enabled: Bool = true) -> Self
    public func force(_ enabled: Bool = true) -> Self
    public func progress(_ enabled: Bool = true) -> Self
    public func all(_ enabled: Bool = true) -> Self
    public func branch(_ value: String) -> Self
    public func name(_ value: String) -> Self
    public func reference(_ repository: String) -> Self
    public func dissociate(_ enabled: Bool = true) -> Self
    public func refFormat(_ value: String) -> Self
    public func depth(_ value: Int) -> Self
    public func initializeOnUpdate(_ enabled: Bool = true) -> Self
    public func remote(_ enabled: Bool = true) -> Self
    public func noFetch(_ enabled: Bool = true) -> Self
    public func updateStrategy(_ value: GitSubmoduleUpdateStrategy) -> Self
    public func jobs(_ value: Int) -> Self
    public func singleBranch(_ enabled: Bool = true) -> Self
    public func noSingleBranch(_ enabled: Bool = true) -> Self
    public func recommendShallow(_ enabled: Bool = true) -> Self
    public func noRecommendShallow(_ enabled: Bool = true) -> Self
    public func filter(_ value: String) -> Self
    public func files(_ enabled: Bool = true) -> Self
    public func summaryLimit(_ value: Int) -> Self
    public func summaryCommit(_ value: String) -> Self
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self
    public func statusEntries() -> Workflow<[GitSubmoduleStatusEntry]>
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitDiff: RunnableCommandFamily {
    public func format(_ value: GitDiffFormat) -> Self
    public func staged(_ enabled: Bool = true) -> Self
    public func range(_ value: String) -> Self
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self
    public func fileChanges() -> Workflow<[GitDiffFileChange]>
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitLog: RunnableCommandFamily {
    public func format(_ value: GitLogFormat) -> Self
    public func maxCount(_ value: Int) -> Self
    public func range(_ value: String) -> Self
    public func entries() -> Workflow<[GitLogEntry]>
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitConfigCommand: RunnableCommandFamily {
    public func get(_ key: String) -> Self
    public func set(_ key: String, to value: String) -> Self
    public func unset(_ key: String) -> Self
    public func list() -> Self
    public func local(_ enabled: Bool = true) -> Self
    public func global(_ enabled: Bool = true) -> Self
    public func format(_ value: GitConfigFormat) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitMerge: RunnableCommandFamily {
    public func branch(_ value: String) -> Self
    public func noFastForward(_ enabled: Bool = true) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitCommit: RunnableCommandFamily {
    public func message(_ value: String) -> Self
    public func all(_ enabled: Bool = true) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitRebase: RunnableCommandFamily {
    public func onto(_ value: String) -> Self
    public func `continue`() -> Self
    public func abort() -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct GitBranchEntry: Sendable {
    public let name: String
    public let isCurrent: Bool
    public let upstream: String?
}

public struct GitLogEntry: Sendable {
    public let commitHash: String
    public let abbreviatedCommitHash: String
    public let authorName: String
    public let authorEmail: String
    public let subject: String
}

public enum GitDiffChangeKind: Sendable, Equatable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case unmerged
    case typeChanged
    case unknown(String)
}

public struct GitDiffFileChange: Sendable {
    public let kind: GitDiffChangeKind
    public let path: String
    public let originalPath: String?
    public let statusCode: String
}

public enum GitSubmoduleStatusState: Sendable, Equatable, Hashable {
    case current
    case uninitialized
    case outOfSync
    case mergeConflicted
    case unknown(String)
}

public struct GitSubmoduleStatusEntry: Sendable {
    public let state: GitSubmoduleStatusState
    public let commitHash: String
    public let path: String
    public let description: String?
}
```

#### Grep

```swift
public enum GrepPattern: Sendable, Equatable, Hashable {
    case literal(String)
    case regularExpression(String)
}

public struct Grep: RunnableCommandFamily {
    public init(_ pattern: String, context: ShellContext = .init())       // literal
    public static func regex(_ pattern: String, context: ShellContext = .init()) -> Self

    // standard fluent overrides (executable, env, workingDirectory, timeout, outputLimit, stdout, stderr)
    public func ignoreCase(_ enabled: Bool = true) -> Self
    public func invertMatch(_ enabled: Bool = true) -> Self
    public func recursive(_ enabled: Bool = true) -> Self
    public func lineNumbers(_ enabled: Bool = true) -> Self
    public func count(_ enabled: Bool = true) -> Self
    public func file(_ path: String) -> Self
    public func files(_ paths: [String]) -> Self

    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### Common File-System Commands

All common command families conform to ``RunnableCommandFamily`` and share the standard
fluent overrides (`executable`, `env`, `workingDirectory`, `timeout`, `outputLimit`,
`stdout`, `stderr`).

```swift
public struct Ls: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func all(_ enabled: Bool = true) -> Self          // -a
    public func longFormat(_ enabled: Bool = true) -> Self   // -l
    public func humanReadable(_ enabled: Bool = true) -> Self // -h
    public func recursive(_ enabled: Bool = true) -> Self    // -R
    public func directoryAsFile(_ enabled: Bool = true) -> Self // -d
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Mkdir: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func parents(_ enabled: Bool = true) -> Self      // -p
    public func mode(_ value: String) -> Self                // -m
    public func directory(_ path: String) -> Self
    public func directories(_ paths: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Rm: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func recursive(_ enabled: Bool = true) -> Self    // -r
    public func force(_ enabled: Bool = true) -> Self        // -f
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Cp: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func recursive(_ enabled: Bool = true) -> Self    // -R
    public func force(_ enabled: Bool = true) -> Self        // -f
    public func source(_ path: String) -> Self
    public func sources(_ paths: [String]) -> Self
    public func destination(_ path: String) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Mv: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func force(_ enabled: Bool = true) -> Self        // -f
    public func source(_ path: String) -> Self
    public func sources(_ paths: [String]) -> Self
    public func destination(_ path: String) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Chmod: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func recursive(_ enabled: Bool = true) -> Self    // -R
    public func mode(_ value: FileMode) -> Self              // typed mode
    public func mode(_ value: String) -> Self                // raw octal/symbolic string
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Pwd: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func physical(_ enabled: Bool = true) -> Self     // -P (resolve symlinks)
    public func logical(_ enabled: Bool = true) -> Self      // -L (preserve symlinks)
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Rsync: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func archive(_ enabled: Bool = true) -> Self       // -a
    public func recursive(_ enabled: Bool = true) -> Self     // -r
    public func compress(_ enabled: Bool = true) -> Self      // -z
    public func verbose(_ enabled: Bool = true) -> Self       // -v
    public func quiet(_ enabled: Bool = true) -> Self         // -q
    public func dryRun(_ enabled: Bool = true) -> Self        // -n
    public func checksum(_ enabled: Bool = true) -> Self      // -c
    public func update(_ enabled: Bool = true) -> Self        // -u
    public func delete(_ enabled: Bool = true) -> Self        // --delete
    public func deleteExcluded(_ enabled: Bool = true) -> Self
    public func links(_ enabled: Bool = true) -> Self         // -l
    public func copyLinks(_ enabled: Bool = true) -> Self     // -L
    public func permissions(_ enabled: Bool = true) -> Self   // -p
    public func times(_ enabled: Bool = true) -> Self         // -t
    public func owner(_ enabled: Bool = true) -> Self         // -o
    public func group(_ enabled: Bool = true) -> Self         // -g
    public func hardLinks(_ enabled: Bool = true) -> Self     // -H
    public func sparse(_ enabled: Bool = true) -> Self        // -S
    public func oneFileSystem(_ enabled: Bool = true) -> Self // -x
    public func itemizeChanges(_ enabled: Bool = true) -> Self // -i
    public func humanReadable(_ enabled: Bool = true) -> Self // -h
    public func progress(_ enabled: Bool = true) -> Self
    public func partial(_ enabled: Bool = true) -> Self
    public func existing(_ enabled: Bool = true) -> Self
    public func ignoreExisting(_ enabled: Bool = true) -> Self
    public func removeSourceFiles(_ enabled: Bool = true) -> Self
    public func source(_ value: String) -> Self
    public func sources(_ values: [String]) -> Self
    public func destination(_ value: String) -> Self
    public func exclude(_ pattern: String) -> Self
    public func excludes(_ patterns: [String]) -> Self
    public func include(_ pattern: String) -> Self
    public func includes(_ patterns: [String]) -> Self
    public func filter(_ rule: String) -> Self
    public func filters(_ rules: [String]) -> Self
    public func excludeFrom(_ path: String) -> Self
    public func includeFrom(_ path: String) -> Self
    public func filesFrom(_ path: String) -> Self
    public func from0(_ enabled: Bool = true) -> Self
    public func remoteShell(_ command: String) -> Self
    public func remoteRsyncPath(_ path: String) -> Self
    public func port(_ value: Int) -> Self
    public func bandwidthLimit(_ rate: String) -> Self
    public func maxSize(_ value: String) -> Self
    public func minSize(_ value: String) -> Self
    public func ioTimeout(_ seconds: Int) -> Self
    public func option(_ value: String) -> Self
    public func options(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### Swift Toolchain

```swift
public enum SwiftSubcommand: Sendable, Equatable, Hashable {
    case version
    case build
    case test
    case run
    case package
    case repl
    case custom(String)
}

public enum SwiftBuildConfiguration: String, Sendable, Equatable, Hashable {
    case debug
    case release
}

public struct Swift: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: SwiftSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func build() -> Self
    public func test() -> Self
    public func runProduct(_ product: String? = nil) -> Self
    public func package(_ subcommand: String? = nil) -> Self
    public func repl() -> Self
    public func version() -> Self
    public func packagePath(_ path: String) -> Self
    public func scratchPath(_ path: String) -> Self
    public func configuration(_ value: SwiftBuildConfiguration) -> Self
    public func target(_ name: String) -> Self
    public func product(_ name: String) -> Self
    public func traits(_ names: [String]) -> Self
    public func traits(_ names: String...) -> Self
    public func enableAllTraits(_ enabled: Bool = true) -> Self
    public func disableDefaultTraits(_ enabled: Bool = true) -> Self
    public func buildTests(_ enabled: Bool = true) -> Self
    public func codeCoverage(_ enabled: Bool = true) -> Self
    public func skipBuild(_ enabled: Bool = true) -> Self
    public func listTests(_ enabled: Bool = true) -> Self
    public func filter(_ pattern: String) -> Self
    public func skip(_ pattern: String) -> Self
    public func jobs(_ count: Int) -> Self
    public func swiftCompilerFlag(_ value: String) -> Self
    public func swiftCompilerFlags(_ values: [String]) -> Self
    public func cCompilerFlag(_ value: String) -> Self
    public func linkerFlag(_ value: String) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### GitHub CLI

```swift
public enum GhSubcommand: String, Sendable, Equatable, Hashable {
    case agentTask
    case agent
    case agents
    case agentTasks
    case alias
    case api
    case attestation
    case auth
    case browse
    case cache
    case completion
    case config
    case copilot
    case extensionCommand
    case gist
    case gpgKey
    case issue
    case label
    case licenses
    case org
    case pr
    case project
    case release
    case repo
    case ruleset
    case run
    case search
    case secret
    case skill
    case sshKey
    case status
    case variable
    case workflow
}

public struct Gh: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func version() -> Self
    public func subcommand(_ value: GhSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func subcommand(_ value: GhSubcommand, _ nested: String) -> Self
    public func subcommand(_ value: String, _ nested: String) -> Self
    public func agentTask(_ nested: String? = nil) -> Self
    public func agent(_ nested: String? = nil) -> Self
    public func agents(_ nested: String? = nil) -> Self
    public func agentTasks(_ nested: String? = nil) -> Self
    public func alias(_ nested: String? = nil) -> Self
    public func api(_ endpoint: String? = nil) -> Self
    public func attestation(_ nested: String? = nil) -> Self
    public func auth(_ nested: String? = nil) -> Self
    public func browse(_ path: String? = nil) -> Self
    public func cache(_ nested: String? = nil) -> Self
    public func completion(_ shell: String? = nil) -> Self
    public func config(_ nested: String? = nil) -> Self
    public func copilot() -> Self
    public func extensionCommand(_ nested: String? = nil) -> Self
    public func gist(_ nested: String? = nil) -> Self
    public func gpgKey(_ nested: String? = nil) -> Self
    public func issue(_ nested: String? = nil) -> Self
    public func label(_ nested: String? = nil) -> Self
    public func licenses() -> Self
    public func org(_ nested: String? = nil) -> Self
    public func pr(_ nested: String? = nil) -> Self
    public func project(_ nested: String? = nil) -> Self
    public func release(_ nested: String? = nil) -> Self
    public func repoCommand(_ nested: String? = nil) -> Self
    public func ruleset(_ nested: String? = nil) -> Self
    public func runCommand(_ nested: String? = nil) -> Self
    public func search(_ nested: String? = nil) -> Self
    public func secret(_ nested: String? = nil) -> Self
    public func skill(_ nested: String? = nil) -> Self
    public func sshKey(_ nested: String? = nil) -> Self
    public func status() -> Self
    public func variable(_ nested: String? = nil) -> Self
    public func workflow(_ nested: String? = nil) -> Self
    public func repo(_ ownerAndName: String) -> Self
    public func hostname(_ value: String) -> Self
    public func json(_ fields: [String]) -> Self
    public func json(_ fields: String...) -> Self
    public func jq(_ expression: String) -> Self
    public func template(_ value: String) -> Self
    public func limit(_ count: Int) -> Self
    public func web(_ enabled: Bool = true) -> Self
    public func confirm(_ enabled: Bool = true) -> Self
    public func silent(_ enabled: Bool = true) -> Self
    public func option(_ name: String) -> Self
    public func option(_ name: String, _ value: String) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### Docker CLI

```swift
public enum DockerSubcommand: String, Sendable, Equatable, Hashable {
    case builder
    case buildx
    case checkpoint
    case compose
    case config
    case container
    case context
    case debug
    case desktop
    case dhi
    case image
    case initialize
    case inspect
    case login
    case logout
    case manifest
    case mcp
    case model
    case network
    case node
    case offload
    case pass
    case plugin
    case sandbox
    case scout
    case search
    case secret
    case service
    case stack
    case swarm
    case system
    case trust
    case version
    case volume
}

public enum DockerBuildProgress: String, Sendable, Equatable, Hashable {
    case auto
    case plain
    case tty
    case rawjson
}

public struct Docker: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: DockerSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func subcommand(_ value: DockerSubcommand, _ nested: String) -> Self
    public func subcommand(_ value: String, _ nested: String) -> Self
    public func buildx(_ nested: String? = nil) -> Self
    public func compose(_ nested: String? = nil) -> Self
    public func container(_ nested: String? = nil) -> Self
    public func image(_ nested: String? = nil) -> Self
    public func initialize() -> Self
    public func debug(_ target: String? = nil) -> Self
    public func mcp(_ nested: String? = nil) -> Self
    public func scout(_ nested: String? = nil) -> Self
    public func system(_ nested: String? = nil) -> Self
    public func version() -> Self
    public func configPath(_ path: String) -> Self
    public func context(_ name: String) -> Self
    public func host(_ value: String) -> Self
    public func logLevel(_ value: String) -> Self
    public func debugMode(_ enabled: Bool = true) -> Self
    public func tls(_ enabled: Bool = true) -> Self
    public func tlsVerify(_ enabled: Bool = true) -> Self
    public func platform(_ value: String) -> Self
    public func file(_ path: String) -> Self
    public func tag(_ name: String) -> Self
    public func tags(_ names: [String]) -> Self
    public func buildArg(_ value: String) -> Self
    public func buildArgs(_ values: [String]) -> Self
    public func progress(_ value: DockerBuildProgress) -> Self
    public func push(_ enabled: Bool = true) -> Self
    public func load(_ enabled: Bool = true) -> Self
    public func pull(_ enabled: Bool = true) -> Self
    public func name(_ value: String) -> Self
    public func removeWhenDone(_ enabled: Bool = true) -> Self
    public func detach(_ enabled: Bool = true) -> Self
    public func interactive(_ enabled: Bool = true) -> Self
    public func tty(_ enabled: Bool = true) -> Self
    public func commandString(_ value: String) -> Self
    public func shell(_ value: String) -> Self
    public func format(_ value: String) -> Self
    public func option(_ name: String) -> Self
    public func option(_ name: String, _ value: String) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### Scripting CLIs

```swift
public struct Make: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func file(_ path: String) -> Self
    public func directory(_ path: String) -> Self
    public func jobs(_ count: Int) -> Self
    public func keepGoing(_ enabled: Bool = true) -> Self
    public func silent(_ enabled: Bool = true) -> Self
    public func dryRun(_ enabled: Bool = true) -> Self
    public func alwaysMake(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func target(_ name: String) -> Self
    public func targets(_ names: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Node: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func version() -> Self
    public func eval(_ code: String) -> Self
    public func printExpression(_ code: String) -> Self
    public func check(_ path: String) -> Self
    public func script(_ path: String) -> Self
    public func require(_ module: String) -> Self
    public func inspect(_ enabled: Bool = true) -> Self
    public func watch(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func scriptArgument(_ value: String) -> Self
    public func scriptArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum NpmSubcommand: String, Sendable, Equatable, Hashable {
    case install
    case ci
    case run
    case test
    case publish
    case exec
    case outdated
    case audit
    case version
}

public struct Npm: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: NpmSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func install() -> Self
    public func ci() -> Self
    public func test() -> Self
    public func exec(_ binary: String? = nil) -> Self
    public func runScript(_ name: String) -> Self
    public func prefix(_ path: String) -> Self
    public func global(_ enabled: Bool = true) -> Self
    public func production(_ enabled: Bool = true) -> Self
    public func ifPresent(_ enabled: Bool = true) -> Self
    public func silent(_ enabled: Bool = true) -> Self
    public func json(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum YarnSubcommand: String, Sendable, Equatable, Hashable {
    case install
    case add
    case remove
    case run
    case test
    case exec
    case dlx
    case workspaces
    case version
}

public struct Yarn: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: YarnSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func install() -> Self
    public func add(_ packages: String...) -> Self
    public func add(_ packages: [String]) -> Self
    public func remove(_ packages: String...) -> Self
    public func remove(_ packages: [String]) -> Self
    public func test() -> Self
    public func exec(_ binary: String? = nil) -> Self
    public func dlx(_ package: String? = nil) -> Self
    public func runScript(_ name: String) -> Self
    public func cwd(_ path: String) -> Self
    public func immutable(_ enabled: Bool = true) -> Self
    public func production(_ enabled: Bool = true) -> Self
    public func silent(_ enabled: Bool = true) -> Self
    public func json(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum PnpmSubcommand: String, Sendable, Equatable, Hashable {
    case install
    case add
    case remove
    case run
    case test
    case exec
    case dlx
    case audit
    case version
}

public struct Pnpm: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: PnpmSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func install() -> Self
    public func add(_ packages: String...) -> Self
    public func add(_ packages: [String]) -> Self
    public func remove(_ packages: String...) -> Self
    public func remove(_ packages: [String]) -> Self
    public func test() -> Self
    public func exec(_ binary: String? = nil) -> Self
    public func dlx(_ package: String? = nil) -> Self
    public func runScript(_ name: String) -> Self
    public func directory(_ path: String) -> Self
    public func filter(_ selector: String) -> Self
    public func recursive(_ enabled: Bool = true) -> Self
    public func ifPresent(_ enabled: Bool = true) -> Self
    public func frozenLockfile(_ enabled: Bool = true) -> Self
    public func production(_ enabled: Bool = true) -> Self
    public func json(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum BunSubcommand: String, Sendable, Equatable, Hashable {
    case run
    case test
    case install
    case add
    case remove
    case build
    case x
    case pm
    case upgrade
}

public struct Bun: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: BunSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func install() -> Self
    public func add(_ packages: String...) -> Self
    public func add(_ packages: [String]) -> Self
    public func remove(_ packages: String...) -> Self
    public func remove(_ packages: [String]) -> Self
    public func test() -> Self
    public func build(_ entrypoints: String...) -> Self
    public func build(_ entrypoints: [String]) -> Self
    public func x(_ binary: String? = nil) -> Self
    public func runScript(_ name: String) -> Self
    public func cwd(_ path: String) -> Self
    public func watch(_ enabled: Bool = true) -> Self
    public func hot(_ enabled: Bool = true) -> Self
    public func production(_ enabled: Bool = true) -> Self
    public func frozenLockfile(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum TerraformSubcommand: String, Sendable, Equatable, Hashable {
    case version
    case initialize
    case plan
    case apply
    case destroy
    case validate
    case format
    case output
    case workspace
}

public struct Terraform: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: TerraformSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func initCommand() -> Self
    public func plan() -> Self
    public func apply() -> Self
    public func destroy() -> Self
    public func validate() -> Self
    public func format() -> Self
    public func output() -> Self
    public func workspace(_ nested: String? = nil) -> Self
    public func chdir(_ path: String) -> Self
    public func input(_ enabled: Bool) -> Self
    public func noColor(_ enabled: Bool = true) -> Self
    public func json(_ enabled: Bool = true) -> Self
    public func autoApprove(_ enabled: Bool = true) -> Self
    public func refresh(_ enabled: Bool) -> Self
    public func `var`(_ assignment: String) -> Self
    public func `var`(_ key: String, _ value: String) -> Self
    public func varFile(_ path: String) -> Self
    public func out(_ path: String) -> Self
    public func target(_ address: String) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum KubectlSubcommand: String, Sendable, Equatable, Hashable {
    case get
    case describe
    case apply
    case delete
    case logs
    case exec
    case rollout
    case config
    case version
}

public struct Kubectl: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func subcommand(_ value: KubectlSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func get(_ resource: String? = nil) -> Self
    public func describe(_ resource: String? = nil) -> Self
    public func apply() -> Self
    public func delete(_ resource: String? = nil) -> Self
    public func logs(_ resource: String? = nil) -> Self
    public func exec(_ resource: String? = nil) -> Self
    public func kubeconfig(_ path: String) -> Self
    public func contextName(_ name: String) -> Self
    public func namespace(_ name: String) -> Self
    public func output(_ format: String) -> Self
    public func filename(_ path: String) -> Self
    public func selector(_ value: String) -> Self
    public func container(_ name: String) -> Self
    public func allNamespaces(_ enabled: Bool = true) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func positionalArgument(_ value: String) -> Self
    public func positionalArguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum HelmOutputFormat: String, Sendable, Equatable, Hashable {
    case table, json, yaml
}

public enum HelmDryRunMode: String, Sendable, Equatable, Hashable {
    case client, server
}

public enum HelmReleaseStatus: String, Sendable, Equatable, Hashable {
    case deployed, failed, pending, uninstalled, superseded, uninstalling
}

public struct Helm: ToolConfigurableCommandFamily {
    public init(context: ShellContext = .init())
    public func namespace(_ name: String) -> Self
    public func kubeContext(_ name: String) -> Self
    public func kubeconfig(_ path: String) -> Self
    public func template(name: String? = nil, chart: String) -> HelmTemplate
    public func lint(chart: String) -> HelmLint
    public func install(release: String, chart: String) -> HelmInstall
    public func upgrade(release: String, chart: String) -> HelmUpgrade
    public func uninstall(_ releases: String...) -> HelmUninstall
    public func list() -> HelmList
    public func status(release: String) -> HelmStatus
}

// Each operation conforms to RunnableCommandFamily. Template, lint, install,
// and upgrade expose ordered valuesFile(s), set, setString, setFile, and setJSON
// methods. Operation-only flags remain on their corresponding builder.

public struct Python: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func version() -> Self
    public func module(_ name: String) -> Self
    public func commandString(_ code: String) -> Self
    public func script(_ path: String) -> Self
    public func isolated(_ enabled: Bool = true) -> Self
    public func unbuffered(_ enabled: Bool = true) -> Self
    public func dontWriteBytecode(_ enabled: Bool = true) -> Self
    public func optimize(_ level: Int = 1) -> Self
    public func option(_ value: String) -> Self
    public func options(_ values: [String]) -> Self
    public func argument(_ value: String) -> Self
    public func arguments(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### Archives (Tar / Zip / Unzip)

```swift
public enum TarCompression: Sendable, Equatable, Hashable {
    case gzip
    case bzip2
    case xz
    case auto
    case custom(String)
}

public enum TarOperation: String, Sendable, Equatable, Hashable {
    case create
    case extract
    case list
    case append
    case update
}

public struct Tar: RunnableCommandFamily {
    public init(context: ShellContext = .init())
    public func create() -> Self
    public func extract() -> Self
    public func list() -> Self
    public func append() -> Self
    public func update() -> Self
    public func operation(_ value: TarOperation) -> Self
    public func file(_ path: String) -> Self
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self
    public func directory(_ path: String) -> Self
    public func gzip() -> Self
    public func bzip2() -> Self
    public func xz() -> Self
    public func autoCompress() -> Self
    public func compression(_ value: TarCompression) -> Self
    public func exclude(_ pattern: String) -> Self
    public func excludes(_ patterns: [String]) -> Self
    public func excludeFrom(_ path: String) -> Self
    public func filesFrom(_ path: String) -> Self
    public func nullTerminatedFiles(_ enabled: Bool = true) -> Self
    public func stripComponents(_ count: Int) -> Self
    public func toStdout(_ enabled: Bool = true) -> Self
    public func verbose(_ enabled: Bool = true) -> Self
    public func verify(_ enabled: Bool = true) -> Self
    public func removeFilesAfterAdding(_ enabled: Bool = true) -> Self
    public func dereferenceSymlinks(_ enabled: Bool = true) -> Self
    public func absoluteNames(_ enabled: Bool = true) -> Self
    public func preservePermissions(_ enabled: Bool = true) -> Self
    public func sameOwner(_ enabled: Bool = true) -> Self
    public func noSameOwner(_ enabled: Bool = true) -> Self
    public func keepOldFiles(_ enabled: Bool = true) -> Self
    public func skipOldFiles(_ enabled: Bool = true) -> Self
    public func overwrite(_ enabled: Bool = true) -> Self
    public func noRecursion(_ enabled: Bool = true) -> Self
    public func oneFileSystem(_ enabled: Bool = true) -> Self
    public func option(_ value: String) -> Self
    public func options(_ values: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public enum ZipCompressionLevel: Sendable, Equatable, Hashable {
    case store      // -0
    case fastest    // -1
    case `default`  // -6
    case best       // -9
    case custom(Int) // clamped to 0...9 at command-build time
}

public struct Zip: RunnableCommandFamily {
    public init(context: ShellContext = .init())

    // Archive + inputs
    public func archive(_ path: String) -> Self
    public func path(_ value: String) -> Self
    public func paths(_ values: [String]) -> Self

    // Mode
    public func update(_ enabled: Bool = true) -> Self        // -u
    public func freshen(_ enabled: Bool = true) -> Self       // -f
    public func delete(_ enabled: Bool = true) -> Self        // -d
    public func move(_ enabled: Bool = true) -> Self          // -m

    // Behavior
    public func recursive(_ enabled: Bool = true) -> Self     // -r
    public func quiet(_ enabled: Bool = true) -> Self         // -q
    public func verbose(_ enabled: Bool = true) -> Self       // -v
    public func junkPaths(_ enabled: Bool = true) -> Self     // -j
    public func storeSymlinks(_ enabled: Bool = true) -> Self // -y
    public func preservePermissions(_ enabled: Bool = true) -> Self // -X

    // Compression and split
    public func compressionLevel(_ level: ZipCompressionLevel) -> Self
    public func splitSize(_ value: String) -> Self            // -s <size>

    // Security
    public func encryptInteractive(_ enabled: Bool = true) -> Self // -e
    public func password(_ value: String) -> Self             // -P <pwd>  (argv-visible)

    // Filtering (positional, after archive+paths)
    public func include(_ pattern: String) -> Self            // -i <pattern>
    public func includes(_ patterns: [String]) -> Self
    public func exclude(_ pattern: String) -> Self            // -x <pattern>
    public func excludes(_ patterns: [String]) -> Self

    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct UnzipEntry: Sendable, Equatable, Hashable {
    public let path: String
    public let size: Int
    public let modified: Date?
    public init(path: String, size: Int, modified: Date?)
}

public struct Unzip: RunnableCommandFamily {
    public init(context: ShellContext = .init())

    // Archive + selection
    public func archive(_ path: String) -> Self
    public func member(_ pattern: String) -> Self
    public func members(_ patterns: [String]) -> Self
    public func exclude(_ pattern: String) -> Self
    public func excludes(_ patterns: [String]) -> Self

    // Mode
    public func list(_ enabled: Bool = true) -> Self          // -l
    public func test(_ enabled: Bool = true) -> Self          // -t
    public func printToStdout(_ enabled: Bool = true) -> Self // -p
    public func freshen(_ enabled: Bool = true) -> Self       // -f
    public func updateOnly(_ enabled: Bool = true) -> Self    // -u

    // Behavior
    public func destination(_ path: String) -> Self           // -d <dir>
    public func overwrite(_ enabled: Bool = true) -> Self     // -o
    public func neverOverwrite(_ enabled: Bool = true) -> Self // -n
    public func quiet(_ enabled: Bool = true) -> Self         // -q
    public func junkPaths(_ enabled: Bool = true) -> Self     // -j
    public func preserveCase(_ enabled: Bool = true) -> Self  // -K
    public func password(_ value: String) -> Self             // -P <pwd>  (argv-visible)

    // Typed listing
    public func entries() -> Workflow<[UnzipEntry]>           // runs `unzip -l` and parses

    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

`Tar` wraps the platform tar implementation for portable create, extract, and list workflows. `Zip` and `Unzip` wrap Info-ZIP binaries and behave identically on macOS (preinstalled) and Linux (`apt install zip unzip`). `Unzip.entries()` returns a reusable ``Workflow`` that parses the standard `unzip -l` table — paths with embedded spaces are preserved, missing timestamps surface as `nil`. SwiftyShell does not feed stdin to commands run by this API, so unattended extracts should pass `overwrite()` or `neverOverwrite()` to avoid `unzip`'s overwrite prompt hanging the call.

#### Brew

```swift
public enum BrewSubcommand: Sendable, Equatable, Hashable {
    case alias
    case analytics
    case autoremove
    case bundle
    case casks
    case cleanup
    case command
    case commands
    case completions
    case config
    case deps
    case desc
    case developer
    case docs
    case doctor
    case fetch
    case formulae
    case gistLogs
    case help
    case home
    case install
    case leaves
    case link
    case list
    case log
    case migrate
    case missing
    case options
    case info
    case outdated
    case pin
    case postinstall
    case readall
    case reinstall
    case search
    case services
    case shellenv
    case source
    case tap
    case tapInfo
    case unalias
    case uninstall
    case unlink
    case unpin
    case untap
    case update
    case updateIfNeeded
    case updateReset
    case upgrade
    case uses
    case whichFormula
    case custom(String)
}

public struct Brew: RunnableCommandFamily {
    public init(context: ShellContext = .init())

    // Subcommand selectors (defaults to `.list`)
    public func subcommand(_ value: BrewSubcommand) -> Self
    public func subcommand(_ value: String) -> Self
    public func install(_ formulae: String...) -> Self
    public func install(_ formulae: [String]) -> Self
    public func uninstall(_ formulae: String...) -> Self
    public func uninstall(_ formulae: [String]) -> Self
    public func upgrade(_ formulae: String...) -> Self
    public func upgrade(_ formulae: [String]) -> Self
    public func update() -> Self
    public func list(_ formulae: String...) -> Self
    public func list(_ formulae: [String]) -> Self
    public func info(_ formulae: String...) -> Self
    public func info(_ formulae: [String]) -> Self
    public func search(_ pattern: String) -> Self
    public func outdated() -> Self

    // Additional positional args and command-specific flags
    public func arg(_ value: String) -> Self
    public func args(_ values: [String]) -> Self
    public func formula(_ name: String) -> Self
    public func formulae(_ names: [String]) -> Self

    // Flags
    public func cask(_ enabled: Bool = true) -> Self         // --cask
    public func formulaFlag(_ enabled: Bool = true) -> Self  // --formula
    public func force(_ enabled: Bool = true) -> Self        // --force
    public func quiet(_ enabled: Bool = true) -> Self        // --quiet
    public func verbose(_ enabled: Bool = true) -> Self      // --verbose
    public func dryRun(_ enabled: Bool = true) -> Self       // --dry-run
    public func greedy(_ enabled: Bool = true) -> Self       // --greedy

    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

Brew emits a raw ``ShellOutput``; typed parsing of `list` / `info` / `outdated`
is not yet provided.

#### Jq

```swift
public struct JqArgument: Sendable, Equatable, Hashable {
    public let name: String
    public let value: String
    public init(name: String, value: String)
}

public struct Jq: RunnableCommandFamily {
    public init(_ filter: String = ".", context: ShellContext = .init())
    public func filter(_ value: String) -> Self
    public func rawOutput(_ enabled: Bool = true) -> Self    // -r
    public func compactOutput(_ enabled: Bool = true) -> Self // -c
    public func slurp(_ enabled: Bool = true) -> Self        // -s
    public func nullInput(_ enabled: Bool = true) -> Self    // -n
    public func sortKeys(_ enabled: Bool = true) -> Self     // -S
    public func arg(_ name: String, _ value: String) -> Self // --arg
    public func file(_ path: String) -> Self
    public func files(_ paths: [String]) -> Self
    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### MockExecutor (for testing)

```swift
public struct MockExecutor: CommandExecutor {
    public typealias Handler = @Sendable (Command, ShellContext) async throws -> ShellOutput

    public init(handler: @escaping Handler)
    public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0)
}

public struct MockSpawnedProcess: SpawnedProcess, Sendable {
    public let processIdentifier: Int32
    public let standardOutput: AsyncStream<String>
    public let standardError: AsyncStream<String>
    public let configuredTeardown: TeardownStrategy

    public init(
        processIdentifier: Int32 = 1,
        teardown: TeardownStrategy = .graceful,
        output: ShellOutput = ShellOutput(exitCode: 0)
    )

    public var signalHistory: [ProcessSignal] { get async }
    public var didTeardown: Bool { get async }
    public func send(_ signal: ProcessSignal) async throws
    public func teardownAndWait() async -> ShellOutput
    public func waitForExit() async -> ShellOutput
}
```

`MockExecutor` mirrors real `run()` semantics for invalid configuration and non-zero exits so unit tests behave like subprocess-backed execution. Its `spawn` support returns `MockSpawnedProcess`, which records signals, teardown, and the configured `TeardownStrategy`.

For pipelines, all stages run concurrently. The shortest resolved stage timeout governs the pipeline, each stage has its own captured-output limit, intermediate stdout is piped rather than captured, and captured stderr is aggregated in stage order. A non-zero stage cancels remaining stage tasks, but simultaneous failures do not guarantee a pipeline-order winner.

`SubprocessExecutor` is the default production executor and is backed by the `swift-subprocess` package. Preserve SwiftyShell's public `ShellError` semantics when changing the execution layer, including captured partial output on timeout, output-limit, and cancellation paths. `run()` closes stdin and immediately sends `SIGKILL` to registered processes when forced to stop; graceful `TeardownStrategy` steps apply only to explicitly spawned processes.

### Code Generation Rules

1. Always `import SwiftyShell`
2. All `run()` calls are `async throws` — the caller must be in an `async` context
3. Never construct raw shell strings as the primary execution model
4. Prefer `Git` when the operation is covered by the typed git API; otherwise use `Command("git", arguments: ...)`
5. Prefer key-path `require` over closure `require` when checking a single property equality
6. Prefer `async let` / `TaskGroup` for concurrent runs — do not serialize what can run in parallel
7. Always pass an explicit `ShellContext` rather than relying on the default `.init()`
8. Workflows can run repeatedly; account for side effects before repeating or running concurrently
9. Use `MockExecutor` in tests — for spawn flows, assert against `MockSpawnedProcess` signal history, teardown state, and configured teardown instead of spawning real processes in unit tests
10. **Every `public` declaration you write must have a `///` doc comment** — see Part 2 for documentation rules

### Worked Examples

```swift
// Simple command
let output = try await Command("mkdir").arg("-p").arg(outputDir).run(in: context)

// Pipeline
let output = try await Command("ls", arguments: "-la")
    .pipe(to: Grep(".swift").command())
    .run(in: context)

// Redirect stdout to file
try await Command("make", arguments: "release")
    .stdout(.file(path: logPath, append: false))
    .run(in: context)

// Spawn a long-running process, then tear it down gracefully
let server = try await Command("python3", arguments: "-m", "http.server", "8080")
    .spawn(in: context, teardown: .graceful)

let serverOutput = await server.teardownAndWait()

// Git status check then pull (key-path require)
try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Git status with closure condition
try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require({ !$0.hasUnstagedChanges }, else: MyError.dirtyTree)
    .fetch()
    .run()

// Concurrent git fetch
let git = Git(context: context)
try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
    for path in repoPaths {
        group.addTask { try await git.workingDirectory(path).fetch().run() }
    }
    for try await _ in group {}
}

// Environment override
try await Command("ruby", arguments: "deploy.rb")
    .env("RAILS_ENV", "production")
    .run(in: context)

// RunnableCommandFamily helpers also support spawn(teardown:)
let grepProcess = try await Grep("ERROR", context: context)
    .file(logPath)
    .spawn(teardown: .immediate)

let grepOutput = await grepProcess.waitForExit()

// File system operations
try await Mkdir(context: context)
    .parents()
    .mode(FileMode(owner: [.read, .write, .execute], group: [.read, .execute], other: [.read, .execute]))
    .directory("/tmp/output")
    .run()
try await Chmod(context: context)
    .mode(FileMode(owner: [.read, .write], group: [.read], other: [.read]))
    .path("/tmp/output/config.json")
    .run()
try await Cp(context: context).recursive().source("build/").destination("/tmp/dist").run()
try await Rm(context: context).recursive().force().path("/tmp/old-build").run()
try await Mv(context: context).source("/tmp/output.log").destination("/var/logs/build.log").run()

// jq — extract a field as raw text
let name = try await Jq(".name", context: context).rawOutput().file("package.json").run()

// Homebrew — install a formula
try await Brew(context: context).install("ripgrep").run()

// Homebrew — check outdated casks
let outdated = try await Brew(context: context).outdated().greedy().run()

// SwiftPM — release build with warnings as errors
try await Swift(context: context)
    .build()
    .configuration(.release)
    .swiftCompilerFlag("-warnings-as-errors")
    .run()

// Rsync — mirror a project directory to a remote host
try await Rsync(context: context)
    .archive()
    .compress()
    .delete()
    .exclude(".build")
    .source("/path/to/project/")
    .destination("deploy@example.com:/srv/project/")
    .run()

// Tar — create a gzip-compressed archive from a project directory
try await Tar(context: context)
    .create()
    .gzip()
    .file("/tmp/source.tar.gz")
    .directory("/path/to/project")
    .exclude(".build")
    .path("Sources")
    .path("Package.swift")
    .run()

// Zip — create a recursive archive at maximum compression
try await Zip(context: context)
    .recursive()
    .compressionLevel(.best)
    .archive("/tmp/release.zip")
    .path("build/")
    .run()

// Unzip — list archive entries with typed parsing
let entries = try await Unzip(context: context)
    .archive("/tmp/release.zip")
    .entries()
    .run()
for entry in entries where entry.path.hasSuffix(".swift") {
    print(entry.path, entry.size)
}

// MockExecutor in tests
let context = ShellContext(executor: MockExecutor(stdout: "main\n"))
let status = try await Git(context: context).status().run()
```

### Error Handling Reference

| Case | Cause | Typical response |
|---|---|---|
| `invalidConfiguration` | Timeout is negative/non-finite, or output limit is negative | Fix the configuration value before running |
| `commandNotFound` | Executable not on search path | Check `ShellContext.searchPaths` or use `.executable(_:)` |
| `exitFailure` | Non-zero exit code | Inspect `output.stderr`; retry or abort |
| `timeout` | Command exceeded time limit | Inspect `partialOutput`, increase timeout |
| `outputLimitExceeded` | Output exceeded configured limit | Raise `outputLimit(_:)` or redirect to file |
| `decodingError` | Output is not valid UTF-8 | Redirect output to file and read as `Data` |
| `cancelled` | Parent Swift task was cancelled | Inspect `partialOutput`, propagate cancellation |
| `workflowConditionFailed` | A `require` predicate returned false | Handle the specific workflow gate |
| `spawnError` | Process could not be launched | Check executable path and permissions |

---

## Part 2: Documentation Requirements — MANDATORY

**Every public declaration must have a `///` doc comment and authored DocC coverage. This is a hard requirement, not a suggestion.**

Doc comments are necessary but not sufficient. When adding or changing public code, command families, command methods, workflows, parser results, or reusable behavior, update `Sources/SwiftyShell/SwiftyShell.docc/` in the same change with discoverable, user-facing documentation and realistic Swift examples.

### What Requires a Doc Comment

- `public struct`, `public class`, `public enum`, `public protocol`
- `public var`, `public let` (properties and stored state)
- `public func`, `public init`
- `public typealias`
- `public case` on enums

### Documentation Rules

1. **Type-level docs** — explain what the type _is_ and when to use it; include a short code example for primary API types
2. **Method-level docs** — explain what the method _does_; call out any non-obvious side effects or semantics
3. **Parameter docs** — use `- Parameter name:` for non-trivial parameters; `- Returns:` when the return value isn't obvious; `- Throws:` listing the `ShellError` cases that can be thrown
4. **Cross-references** — use ``SymbolName`` double-backtick syntax to link related types
5. **Examples in doc comments** — include `///` code fences (` ``` swift `) in type-level docs for all public-facing types
6. **Authored DocC** — link every public top-level symbol from a `.docc` Markdown page
7. **Command family DocC** — every public command family must have a dedicated or grouped DocC page with realistic Swift examples and a `## Topics` section
8. **No command without docs** — do not add a new command family, fluent command method, typed workflow, or structured result without adding or updating DocC examples that show how users should call it

### Verification Step

After writing or modifying any Swift file, scan every line that starts with `public ` and confirm it is immediately preceded (allowing for `@` attributes and blank lines) by a `///` doc comment. Then run `swift -warnings-as-errors Scripts/validate-docc-coverage.swift` to confirm public symbols and command families are covered by authored DocC. If anything is missing, add it before finishing.

### Example of Correct Documentation

```swift
/// A typed entry point for running `git` commands with structured results.
///
/// ```swift
/// let status = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .run()
/// ```
public struct Git: ToolConfigurableCommandFamily {

    /// Returns a workflow that queries the current working-tree status.
    ///
    /// - Returns: A ``GitStatusWorkflow`` that produces a ``GitStatus`` on success.
    public func status() -> GitStatusWorkflow { ... }

    /// Pulls the current branch from its upstream remote.
    ///
    /// - Returns: A ``Workflow`` that produces a ``GitPullResult``.
    /// - Throws: ``ShellError/exitFailure(_:_:)`` when the pull fails (e.g. merge conflict,
    ///   unreachable remote).
    public func pull() -> Workflow<GitPullResult> { ... }
}
```

---

## Part 3: Authoring New Command Families

Use this section when adding or revising command families.

### Goals

- Preserve SwiftyShell's fluent, immutable value-type API style
- Keep command family state private; derive shell arguments only in `command()`
- Make it easy for other contributors to add new command wrappers consistently

### Authoring Rules

1. New command families must be value types (`struct`) and `Sendable`
2. Do not expose stored configuration as public properties unless it is part of the intended API surface
3. Store state privately; use non-`mutating` fluent methods that return a new value
4. If the command supports tool config overrides, conform to `ToolConfigurableCommandFamily`
5. If the command supports stdout/stderr redirection, conform to `OutputRedirectingCommandFamily`
6. If the command can materialize a `Command`, conform to `RunnableCommandFamily`
7. Build argv in exactly one place: `command()`
8. Prefer semantic methods like `.source(_:)`, `.destination(_:)` over raw option strings
9. Add tests for both command building and real execution where practical
10. **Every `public` declaration must have a `///` doc comment** — apply documentation rules from Part 2
11. **Add authored DocC** — every new command family or public command method must be documented in `Sources/SwiftyShell/SwiftyShell.docc/` with practical Swift examples and topic links
12. **Wire the trait** — every new family must have a matching SwiftPM trait. See Part 4.

### Recommended Structure

```swift
import Foundation

public struct ExampleTool: RunnableCommandFamily {
    private let state: State

    public var context: ShellContext { state.config.context }

    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        with(config: update(state.config))
    }

    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        with(stdoutDestination: destination)
    }

    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        with(stderrDestination: destination)
    }

    public func verbose(_ enabled: Bool = true) -> Self {
        with(isVerbose: enabled)
    }

    public func file(_ path: String) -> Self {
        with(files: state.files + [path])
    }

    public func command() -> Command {
        var arguments: [String] = []
        if state.isVerbose { arguments.append("--verbose") }
        arguments.append(contentsOf: state.files)

        let base = Command("example-tool")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func with(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isVerbose: Bool? = nil,
        files: [String]? = nil
    ) -> Self {
        Self(state: State(
            config: config ?? state.config,
            stdoutDestination: stdoutDestination ?? state.stdoutDestination,
            stderrDestination: stderrDestination ?? state.stderrDestination,
            isVerbose: isVerbose ?? state.isVerbose,
            files: files ?? state.files
        ))
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isVerbose: Bool
    let files: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isVerbose: Bool = false,
        files: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isVerbose = isVerbose
        self.files = files
    }
}
```

### Test Checklist

For every new command family:

- Builder test that checks `command().arguments`
- At least one execution test if the tool is expected in the environment
- If the tool may be missing, gate the execution test safely
- MockExecutor-based unit tests for typed workflow clients

---

## Part 4: Package Traits — MANDATORY for new families

SwiftyShell uses [SwiftPM Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) so each typed command family is opt-in. The default trait set is **empty** — only `Core/` and `Internal/` types compile when no trait is selected.

### Trait Inventory

Declared in `Package.swift`:

- **Per-family** — `Git`, `Brew`, `Grep`, `Fzf`, `Rg`, `Swift`, `Gh`, `Docker`, `Make`, `Node`, `Npm`, `Yarn`, `Pnpm`, `Bun`, `Terraform`, `Kubectl`, `Helm`, `Python`, `Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Jq`, `Rsync`, `Tar`, `Zip`, `Unzip`. One trait per family directory; for `Common/`, one trait per file.
- **Umbrellas** — `CommonUtilities` (every `Common/*` family), `All` (every command family).

Consumers select families with `traits:` on `.package(...)`:

```swift
.package(url: "...", from: "0.3.0", traits: ["Git", "Grep"])
```

### Wiring Contract

The contract is enforced by `Scripts/validate-traits.swift` and CI:

1. Every `.swift` file under a gated source directory (`Git/`, `Brew/`, `Grep/`, `Fzf/`, `Rg/`, `Swift/`, `Gh/`, `Docker/`, `Make/`, `Node/`, `Npm/`, `Yarn/`, `Pnpm/`, `Bun/`, `Terraform/`, `Kubectl/`, `Helm/`, `Python/`, and each file in `Common/`) is wrapped top-to-bottom in `#if <Trait> ... #endif`.
2. Every test file targeting a gated family is wrapped the same way. Cross-family tests use combined guards (`#if Git && Grep`).
3. Every family directory (or `Common/*.swift` file) has a matching `.trait(name:)` entry in `Package.swift`.
4. The `All` umbrella's `enabledTraits` transitively enables every per-family trait. The `CommonUtilities` umbrella enables every `Common/*` trait.
5. `Core/` and `Internal/` files are **never** gated.

### Adding a New Family — Trait Steps

In addition to the implementation steps in Part 3:

1. Wrap every source file in the new family with `#if <Family> ... #endif`.
2. Add `.trait(name: "<Family>", description: "...")` to the `traits:` array in `Package.swift`.
3. Add `<Family>` to the `All` umbrella's `enabledTraits`. If it lives under `Common/`, also add it to `CommonUtilities`.
4. Wrap every test file for the new family in `#if <Family>`. For cross-family tests, use combined guards.
5. Run `swift -warnings-as-errors Scripts/validate-traits.swift` — it must exit clean.
6. Verify builds and tests under the relevant trait selections:

```bash
swift build -c release -Xswiftc -warnings-as-errors                          # default (no trait selected)
swift build -c release -Xswiftc -warnings-as-errors --traits <Family>        # the new trait alone
swift test -Xswiftc -warnings-as-errors --traits <Family>
swift build -c release -Xswiftc -warnings-as-errors --enable-all-traits      # full matrix
swift test -Xswiftc -warnings-as-errors --enable-all-traits
```

7. If the new family has real execution tests that require an external CLI binary, update `.github/workflows/reusable-ci.yml` in the same change so CI installs that tool for the family trait, the `All` umbrella build/test jobs, and coverage runs that use `--enable-all-traits`. Keep macOS Homebrew installs and Linux package installs aligned.

### Common Mistakes

- **Forgetting the `#if` wrap on test files** — the test target won't compile under selective trait sets. The validator will catch this.
- **Adding the trait declaration but not updating `All`** — consumers that opt into `All` won't see the new family. The validator checks `All`'s transitive enablement.
- **Gating files under `Core/` or `Internal/`** — these are always available; never wrap them in `#if`.
- **Cross-family code in `Core/`** — `Core/` must not reference any gated type outside doc-comment code blocks. If a `Core/` type needs to call a typed family, redesign so the family extends `Core/` rather than the other way around.

The pull-request template (`.github/PULL_REQUEST_TEMPLATE.md`) has a checklist that mirrors these steps. CI runs `validate-traits` first and then a build/test matrix; a new family that bypasses the wiring will fail validation before any build runs.

---

## Skill Maintenance

`AGENTS.md` points Codex/GPT-style assistants at this file, so the shared agent guidance lives across both files.

Update `AGENTS.md` and this file together in the same PR whenever shared agent guidance changes, and always update this file in the same PR as any public API change:
- New typed client or method added
- Method signature changed
- `ShellError` cases added or renamed
- Execution semantics changed (pipeline exit, environment merging, etc.)
- New reusable command-family protocol introduced

The skill must reflect the implemented API, not the spec.

## Documentation Checklist

Before submitting any change to this codebase, verify:

- [ ] Every `public` type, property, method, init, and enum case has a `///` doc comment
- [ ] Type-level docs include a code example for primary API surface types
- [ ] Non-trivial parameters have `- Parameter name:` documentation
- [ ] Methods that throw list the `ShellError` cases they can throw with `- Throws:`
- [ ] Cross-references use ``SymbolName`` double-backtick syntax
- [ ] Authored DocC links every new public symbol and includes practical examples for every new command family or command method
- [ ] `swift -warnings-as-errors Scripts/validate-docc-coverage.swift` exits clean
- [ ] `AGENTS.md` is updated if shared agent guidance changed
- [ ] The skill file (`.claude/skills/swiftyshell.md`) is updated if public API or shared agent guidance changed
- [ ] If a new command family was added: source + tests are wrapped in `#if <Family>`, the trait is declared in `Package.swift`, `All` (and `CommonUtilities` if applicable) include it, and `swift -warnings-as-errors Scripts/validate-traits.swift` exits clean

## Hard Gate: Tests + swift-format + DocC

A change is not done — do not declare completion, open a PR, or hand back to the user — until these gates pass on every file you touched:

1. `swift test -Xswiftc -warnings-as-errors` — all tests green.
2. `swift-format lint --strict` — no errors on changed Swift files. For new Swift, run `swift-format format -i <file>` first to auto-fix, then re-lint. Do not run `swift-format` on DocC Markdown; validate `.docc/*.md` changes with DocC coverage and generation instead.
3. `swift -warnings-as-errors Scripts/validate-docc-coverage.swift` — authored DocC links and command-family examples are present.
4. `swift package -Xswiftc -warnings-as-errors --allow-writing-to-directory docs generate-documentation --target SwiftyShell --output-path docs --transform-for-static-hosting --hosting-base-path SwiftyShell` — DocC builds cleanly when public API or DocC content changes.

The repo ships a `.swift-format` config at the root; use it for Swift source. The tree is currently fully compliant (`swift-format lint --strict --recursive Sources Tests Scripts` exits clean) — keep it that way. `swift-format` parses inputs as Swift, so Markdown-only documentation changes should use the DocC validation gates rather than direct Markdown linting with `swift-format`. If a lint rule is genuinely wrong for a specific Swift construct, update `.swift-format` in the same change rather than skipping the gate.
