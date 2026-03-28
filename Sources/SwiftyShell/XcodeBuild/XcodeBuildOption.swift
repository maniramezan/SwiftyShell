import Foundation

/// A typed `xcodebuild` option and its raw arguments.
public struct XcodeBuildOption: Sendable, Equatable, Hashable {
    /// The raw arguments emitted for the option.
    public let arguments: [String]

    /// Creates an `xcodebuild` option from raw arguments.
    public init(_ arguments: String...) {
        precondition(!arguments.isEmpty, "An xcodebuild option must include at least one argument.")
        self.arguments = arguments
    }

    private init(arguments: [String]) {
        precondition(!arguments.isEmpty, "An xcodebuild option must include at least one argument.")
        self.arguments = arguments
    }

    /// Creates a custom `xcodebuild` option.
    public static func custom(_ flag: String, values: String...) -> Self {
        Self(arguments: [flag] + values)
    }

    /// Emits `-usage`.
    public static let usage = Self("-usage")
    /// Emits `-help`.
    public static let help = Self("-help")
    /// Emits `-verbose`.
    public static let verbose = Self("-verbose")
    /// Emits `-license`.
    public static let license = Self("-license")
    /// Emits `-checkFirstLaunchStatus`.
    public static let checkFirstLaunchStatus = Self("-checkFirstLaunchStatus")
    /// Emits `-runFirstLaunch`.
    public static let runFirstLaunch = Self("-runFirstLaunch")
    /// Emits `-downloadAllPlatforms`.
    public static let downloadAllPlatforms = Self("-downloadAllPlatforms")
    /// Emits `-prepareDeviceSupport`.
    public static let prepareDeviceSupport = Self("-prepareDeviceSupport")
    /// Emits `-platform <value>`.
    public static func platform(_ value: String) -> Self {
        Self("-platform", value)
    }
    /// Emits `-osVersion <value>`.
    public static func osVersion(_ value: String) -> Self {
        Self("-osVersion", value)
    }
    /// Emits `-modelCode <value>`.
    public static func modelCode(_ value: String) -> Self {
        Self("-modelCode", value)
    }
    /// Emits `-architecture <value>`.
    public static func architecture(_ value: String) -> Self {
        Self("-architecture", value)
    }
    /// Emits `-downloadPlatform <value>`.
    public static func downloadPlatform(_ value: String) -> Self {
        Self("-downloadPlatform", value)
    }
    /// Emits `-importPlatform <value>`.
    public static func importPlatform(_ value: String) -> Self {
        Self("-importPlatform", value)
    }
    /// Emits `-downloadComponent <value>`.
    public static func downloadComponent(_ value: String) -> Self {
        Self("-downloadComponent", value)
    }
    /// Emits `-importComponent <value>`.
    public static func importComponent(_ value: String) -> Self {
        Self("-importComponent", value)
    }
    /// Emits `-deleteComponent <value>`.
    public static func deleteComponent(_ value: String) -> Self {
        Self("-deleteComponent", value)
    }
    /// Emits `-showComponent <value>`.
    public static func showComponent(_ value: String) -> Self {
        Self("-showComponent", value)
    }
    /// Emits `-project <value>`.
    public static func project(_ value: String) -> Self {
        Self("-project", value)
    }
    /// Emits `-target <value>`.
    public static func target(_ value: String) -> Self {
        Self("-target", value)
    }
    /// Emits `-alltargets`.
    public static let allTargets = Self("-alltargets")
    /// Emits `-workspace <value>`.
    public static func workspace(_ value: String) -> Self {
        Self("-workspace", value)
    }
    /// Emits `-scheme <value>`.
    public static func scheme(_ value: String) -> Self {
        Self("-scheme", value)
    }
    /// Emits `-configuration <value>`.
    public static func configuration(_ value: String) -> Self {
        Self("-configuration", value)
    }
    /// Emits `-xcconfig <value>`.
    public static func xcconfig(_ value: String) -> Self {
        Self("-xcconfig", value)
    }
    /// Emits `-arch <value>`.
    public static func arch(_ value: String) -> Self {
        Self("-arch", value)
    }
    /// Emits `-sdk` with an optional value.
    public static func sdk(_ value: String? = nil) -> Self {
        if let value {
            return Self("-sdk", value)
        }
        return Self("-sdk")
    }
    /// Emits `-toolchain <value>`.
    public static func toolchain(_ value: String) -> Self {
        Self("-toolchain", value)
    }
    /// Emits `-destination <value>`.
    public static func destination(_ value: String) -> Self {
        Self("-destination", value)
    }
    /// Emits `-destination-timeout <value>`.
    public static func destinationTimeout(_ value: String) -> Self {
        Self("-destination-timeout", value)
    }
    /// Emits `-parallelizeTargets`.
    public static let parallelizeTargets = Self("-parallelizeTargets")
    /// Emits `-jobs <value>`.
    public static func jobs(_ value: String) -> Self {
        Self("-jobs", value)
    }
    /// Emits `-maximum-concurrent-test-device-destinations <value>`.
    public static func maximumConcurrentTestDeviceDestinations(_ value: String) -> Self {
        Self("-maximum-concurrent-test-device-destinations", value)
    }
    /// Emits `-maximum-concurrent-test-simulator-destinations <value>`.
    public static func maximumConcurrentTestSimulatorDestinations(_ value: String) -> Self {
        Self("-maximum-concurrent-test-simulator-destinations", value)
    }
    /// Emits `-parallel-testing-enabled <value>`.
    public static func parallelTestingEnabled(_ value: String) -> Self {
        Self("-parallel-testing-enabled", value)
    }
    /// Emits `-parallel-testing-worker-count <value>`.
    public static func parallelTestingWorkerCount(_ value: String) -> Self {
        Self("-parallel-testing-worker-count", value)
    }
    /// Emits `-maximum-parallel-testing-workers <value>`.
    public static func maximumParallelTestingWorkers(_ value: String) -> Self {
        Self("-maximum-parallel-testing-workers", value)
    }
    /// Emits `-quiet`.
    public static let quiet = Self("-quiet")
    /// Emits `-hideShellScriptEnvironment`.
    public static let hideShellScriptEnvironment = Self("-hideShellScriptEnvironment")
    /// Emits `-showsdks`.
    public static let showSDKs = Self("-showsdks")
    /// Emits `-showdestinations`.
    public static let showDestinations = Self("-showdestinations")
    /// Emits `-showTestPlans`.
    public static let showTestPlans = Self("-showTestPlans")
    /// Emits `-showBuildSettings`.
    public static let showBuildSettings = Self("-showBuildSettings")
    /// Emits `-showBuildSettingsForIndex`.
    public static let showBuildSettingsForIndex = Self("-showBuildSettingsForIndex")
    /// Emits `-list`.
    public static let list = Self("-list")
    /// Emits `-find-executable <value>`.
    public static func findExecutable(_ value: String) -> Self {
        Self("-find-executable", value)
    }
    /// Emits `-find-library <value>`.
    public static func findLibrary(_ value: String) -> Self {
        Self("-find-library", value)
    }
    /// Emits `-version`.
    public static let version = Self("-version")
    /// Emits `-enableAddressSanitizer <value>`.
    public static func enableAddressSanitizer(_ value: String) -> Self {
        Self("-enableAddressSanitizer", value)
    }
    /// Emits `-enableThreadSanitizer <value>`.
    public static func enableThreadSanitizer(_ value: String) -> Self {
        Self("-enableThreadSanitizer", value)
    }
    /// Emits `-enableUndefinedBehaviorSanitizer <value>`.
    public static func enableUndefinedBehaviorSanitizer(_ value: String) -> Self {
        Self("-enableUndefinedBehaviorSanitizer", value)
    }
    /// Emits `-resultBundlePath <value>`.
    public static func resultBundlePath(_ value: String) -> Self {
        Self("-resultBundlePath", value)
    }
    /// Emits `-resultStreamPath <value>`.
    public static func resultStreamPath(_ value: String) -> Self {
        Self("-resultStreamPath", value)
    }
    /// Emits `-resultBundleVersion <value>`.
    public static func resultBundleVersion(_ value: String) -> Self {
        Self("-resultBundleVersion", value)
    }
    /// Emits `-clonedSourcePackagesDirPath <value>`.
    public static func clonedSourcePackagesDirPath(_ value: String) -> Self {
        Self("-clonedSourcePackagesDirPath", value)
    }
    /// Emits `-derivedDataPath <value>`.
    public static func derivedDataPath(_ value: String) -> Self {
        Self("-derivedDataPath", value)
    }
    /// Emits `-archivePath <value>`.
    public static func archivePath(_ value: String) -> Self {
        Self("-archivePath", value)
    }
    /// Emits `-exportArchive`.
    public static let exportArchive = Self("-exportArchive")
    /// Emits `-exportNotarizedApp`.
    public static let exportNotarizedApp = Self("-exportNotarizedApp")
    /// Emits `-exportOptionsPlist <value>`.
    public static func exportOptionsPlist(_ value: String) -> Self {
        Self("-exportOptionsPlist", value)
    }
    /// Emits `-enableCodeCoverage <value>`.
    public static func enableCodeCoverage(_ value: String) -> Self {
        Self("-enableCodeCoverage", value)
    }
    /// Emits `-exportPath <value>`.
    public static func exportPath(_ value: String) -> Self {
        Self("-exportPath", value)
    }
    /// Emits `-importPath <value>`.
    public static func importPath(_ value: String) -> Self {
        Self("-importPath", value)
    }
    /// Emits `-skipUnavailableActions`.
    public static let skipUnavailableActions = Self("-skipUnavailableActions")
    /// Emits `-exportLocalizations`.
    public static let exportLocalizations = Self("-exportLocalizations")
    /// Emits `-importLocalizations`.
    public static let importLocalizations = Self("-importLocalizations")
    /// Emits `-localizationPath <value>`.
    public static func localizationPath(_ value: String) -> Self {
        Self("-localizationPath", value)
    }
    /// Emits `-exportLanguage <value>`.
    public static func exportLanguage(_ value: String) -> Self {
        Self("-exportLanguage", value)
    }
    /// Emits `-defaultLanguage <value>`.
    public static func defaultLanguage(_ value: String) -> Self {
        Self("-defaultLanguage", value)
    }
    /// Emits `-xctestrun <value>`.
    public static func xctestrun(_ value: String) -> Self {
        Self("-xctestrun", value)
    }
    /// Emits `-testProductsPath <value>`.
    public static func testProductsPath(_ value: String) -> Self {
        Self("-testProductsPath", value)
    }
    /// Emits `-enablePerformanceTestsDiagnostics <value>`.
    public static func enablePerformanceTestsDiagnostics(_ value: String) -> Self {
        Self("-enablePerformanceTestsDiagnostics", value)
    }
    /// Emits `-testPlan <value>`.
    public static func testPlan(_ value: String) -> Self {
        Self("-testPlan", value)
    }
    /// Emits `-only-testing <value>`.
    public static func onlyTesting(_ value: String) -> Self {
        Self("-only-testing", value)
    }
    /// Emits `-only-testing:TEST-IDENTIFIER <value>`.
    public static func onlyTestingIdentifier(_ value: String) -> Self {
        Self("-only-testing:TEST-IDENTIFIER", value)
    }
    /// Emits `-skip-testing <value>`.
    public static func skipTesting(_ value: String) -> Self {
        Self("-skip-testing", value)
    }
    /// Emits `-skip-testing:TEST-IDENTIFIER <value>`.
    public static func skipTestingIdentifier(_ value: String) -> Self {
        Self("-skip-testing:TEST-IDENTIFIER", value)
    }
    /// Emits `-test-timeouts-enabled <value>`.
    public static func testTimeoutsEnabled(_ value: String) -> Self {
        Self("-test-timeouts-enabled", value)
    }
    /// Emits `-default-test-execution-time-allowance <value>`.
    public static func defaultTestExecutionTimeAllowance(_ value: String) -> Self {
        Self("-default-test-execution-time-allowance", value)
    }
    /// Emits `-maximum-test-execution-time-allowance <value>`.
    public static func maximumTestExecutionTimeAllowance(_ value: String) -> Self {
        Self("-maximum-test-execution-time-allowance", value)
    }
    /// Emits `-test-iterations <value>`.
    public static func testIterations(_ value: String) -> Self {
        Self("-test-iterations", value)
    }
    /// Emits `-retry-tests-on-failure`.
    public static let retryTestsOnFailure = Self("-retry-tests-on-failure")
    /// Emits `-run-tests-until-failure`.
    public static let runTestsUntilFailure = Self("-run-tests-until-failure")
    /// Emits `-test-repetition-relaunch-enabled <value>`.
    public static func testRepetitionRelaunchEnabled(_ value: String) -> Self {
        Self("-test-repetition-relaunch-enabled", value)
    }
    /// Emits `-only-test-configuration <value>`.
    public static func onlyTestConfiguration(_ value: String) -> Self {
        Self("-only-test-configuration", value)
    }
    /// Emits `-skip-test-configuration <value>`.
    public static func skipTestConfiguration(_ value: String) -> Self {
        Self("-skip-test-configuration", value)
    }
    /// Emits `-collect-test-diagnostics <value>`.
    public static func collectTestDiagnostics(_ value: String) -> Self {
        Self("-collect-test-diagnostics", value)
    }
    /// Emits `-testLanguage <value>`.
    public static func testLanguage(_ value: String) -> Self {
        Self("-testLanguage", value)
    }
    /// Emits `-testRegion <value>`.
    public static func testRegion(_ value: String) -> Self {
        Self("-testRegion", value)
    }
    /// Emits `-enumerate-tests`.
    public static let enumerateTests = Self("-enumerate-tests")
    /// Emits `-test-enumeration-style <value>`.
    public static func testEnumerationStyle(_ value: String) -> Self {
        Self("-test-enumeration-style", value)
    }
    /// Emits `-test-enumeration-format <value>`.
    public static func testEnumerationFormat(_ value: String) -> Self {
        Self("-test-enumeration-format", value)
    }
    /// Emits `-test-enumeration-output-path <value>`.
    public static func testEnumerationOutputPath(_ value: String) -> Self {
        Self("-test-enumeration-output-path", value)
    }
    /// Emits `-resolvePackageDependencies`.
    public static let resolvePackageDependencies = Self("-resolvePackageDependencies")
    /// Emits `-disableAutomaticPackageResolution`.
    public static let disableAutomaticPackageResolution = Self("-disableAutomaticPackageResolution")
    /// Emits `-onlyUsePackageVersionsFromResolvedFile`.
    public static let onlyUsePackageVersionsFromResolvedFile = Self("-onlyUsePackageVersionsFromResolvedFile")
    /// Emits `-skipPackageUpdates`.
    public static let skipPackageUpdates = Self("-skipPackageUpdates")
    /// Emits `-disablePackageRepositoryCache`.
    public static let disablePackageRepositoryCache = Self("-disablePackageRepositoryCache")
    /// Emits `-skipPackagePluginValidation`.
    public static let skipPackagePluginValidation = Self("-skipPackagePluginValidation")
    /// Emits `-skipMacroValidation`.
    public static let skipMacroValidation = Self("-skipMacroValidation")
    /// Emits `-packageCachePath <value>`.
    public static func packageCachePath(_ value: String) -> Self {
        Self("-packageCachePath", value)
    }
    /// Emits `-packageAuthorizationProvider <value>`.
    public static func packageAuthorizationProvider(_ value: String) -> Self {
        Self("-packageAuthorizationProvider", value)
    }
    /// Emits `-defaultPackageRegistryURL <value>`.
    public static func defaultPackageRegistryURL(_ value: String) -> Self {
        Self("-defaultPackageRegistryURL", value)
    }
    /// Emits `-packageDependencySCMToRegistryTransformation <value>`.
    public static func packageDependencySCMToRegistryTransformation(_ value: String) -> Self {
        Self("-packageDependencySCMToRegistryTransformation", value)
    }
    /// Emits `-skipPackageSignatureValidation`.
    public static let skipPackageSignatureValidation = Self("-skipPackageSignatureValidation")
    /// Emits `-packageFingerprintPolicy <value>`.
    public static func packageFingerprintPolicy(_ value: String) -> Self {
        Self("-packageFingerprintPolicy", value)
    }
    /// Emits `-packageSigningEntityPolicy <value>`.
    public static func packageSigningEntityPolicy(_ value: String) -> Self {
        Self("-packageSigningEntityPolicy", value)
    }
    /// Emits `-json`.
    public static let json = Self("-json")
    /// Emits `-allowProvisioningUpdates`.
    public static let allowProvisioningUpdates = Self("-allowProvisioningUpdates")
    /// Emits `-allowProvisioningDeviceRegistration`.
    public static let allowProvisioningDeviceRegistration = Self("-allowProvisioningDeviceRegistration")
    /// Emits `-authenticationKeyPath <value>`.
    public static func authenticationKeyPath(_ value: String) -> Self {
        Self("-authenticationKeyPath", value)
    }
    /// Emits `-authenticationKeyID <value>`.
    public static func authenticationKeyID(_ value: String) -> Self {
        Self("-authenticationKeyID", value)
    }
    /// Emits `-authenticationKeyIssuerID <value>`.
    public static func authenticationKeyIssuerID(_ value: String) -> Self {
        Self("-authenticationKeyIssuerID", value)
    }
    /// Emits `-scmProvider <value>`.
    public static func scmProvider(_ value: String) -> Self {
        Self("-scmProvider", value)
    }
    /// Emits `-showBuildTimingSummary`.
    public static let showBuildTimingSummary = Self("-showBuildTimingSummary")
    /// Emits `-create-xcframework`.
    public static let createXCFramework = Self("-create-xcframework")
    /// Emits `-architectureVariant <value>`.
    public static func architectureVariant(_ value: String) -> Self {
        Self("-architectureVariant", value)
    }
    /// Emits `-buildVersion <value>`.
    public static func buildVersion(_ value: String) -> Self {
        Self("-buildVersion", value)
    }
    /// Emits `-checkForNewerComponents`.
    public static let checkForNewerComponents = Self("-checkForNewerComponents")
    /// Emits `-includeScreenshots`.
    public static let includeScreenshots = Self("-includeScreenshots")
    /// Emits `-mergeImport`.
    public static let mergeImport = Self("-mergeImport")
    /// Emits `-archive <value>`.
    public static func archive(_ value: String) -> Self {
        Self("-archive", value)
    }
    /// Emits `-framework <value>`.
    public static func framework(_ value: String) -> Self {
        Self("-framework", value)
    }
    /// Emits `-library <value>`.
    public static func library(_ value: String) -> Self {
        Self("-library", value)
    }
    /// Emits `-headers <value>`.
    public static func headers(_ value: String) -> Self {
        Self("-headers", value)
    }
    /// Emits `-debug-symbols <value>`.
    public static func debugSymbols(_ value: String) -> Self {
        Self("-debug-symbols", value)
    }
    /// Emits `-output <value>`.
    public static func output(_ value: String) -> Self {
        Self("-output", value)
    }
    /// Emits `-allow-internal-distribution`.
    public static let allowInternalDistribution = Self("-allow-internal-distribution")
}
