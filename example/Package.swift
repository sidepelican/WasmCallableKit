// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftLib",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MySwiftLib", targets: ["MySwiftLib"]),
    ],
    dependencies: [
        .package(path: "../"),
    ],
    targets: [
        .executableTarget(
            name: "MySwiftLib",
            dependencies: [
                .product(name: "WasmCallableKit", package: "WasmCallableKit"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xclang-linker", "-mexec-model=reactor",
                    "-Xlinker", "--export=main",
                ])
            ]
        ),
        .plugin(
            name: "CodegenPlugin",
            capability: .command(
                intent: .custom(verb: "codegen", description: "Generate codes from Sources/APIDefinition"),
                permissions: [.writeToPackageDirectory(reason: "Place generated code")]
            ),
            dependencies: [
                .product(name: "codegen", package: "WasmCallableKit"),
            ]
        )
    ]
)
