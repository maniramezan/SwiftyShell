// swift-tools-version: 6.3
// Benchmarks live in a separate package so SwiftyShell itself does not depend on package-benchmark.
// Run from this directory: `swift package benchmark` (see README.md).

import PackageDescription

let package = Package(
    name: "SwiftyShellBenchmarks",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.36.2"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftyShellBenchmarks",
            dependencies: [
                .product(name: "SwiftyShell", package: "SwiftyShell"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/SwiftyShellBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
