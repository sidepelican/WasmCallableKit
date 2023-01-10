// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "WasmCallableKit",
    products: [
        .library(name: "WasmCallableKit", targets: ["WasmCallableKit"]),
    ],
    dependencies: [
        .package(path: "Codegen"),
    ],
    targets: [
        .target(name: "WasmCallableKit", dependencies: ["CWasmCallableKit"]),
        .target(name: "CWasmCallableKit"),
    ]
)
