import ArgumentParser
import Foundation
import SwiftTypeReader

enum CodegenError: Error {
    case moduleNameNotFound
}

struct ValidationError: Error, CustomStringConvertible {
    init(_ description: String) {
        self.description = description
    }
    var description: String
}

@main struct Codegen: ParsableCommand {
    @Argument
    var wasmExportsFile: URL

    @Option(help: "generate typescript runtime", completion: .directory)
    var ts_out: URL?

    @Option(help: "generate swift adapter", completion: .directory)
    var swift_out: URL?

    @Option(name: .shortAndLong, help: "module name")
    var module: String?

    mutating func run() throws {
        let moduleName = wasmExportsFile
            .resolvingSymlinksInPath()
            .pathComponents
            .eachPairs()
            .first { (f, s) in
                f == "Sources"
            }
            .map(\.1)
        guard let moduleName = module ?? moduleName else {
            throw CodegenError.moduleNameNotFound
        }

        let module = Reader()
        let result = try module.read(file: wasmExportsFile)

        // validations

        guard let exportsProtocol = result.module.types.first(where: { stype in
            stype.protocol != nil
            && stype.name == "WasmExports"
        })?.protocol else {
            throw ValidationError("'WasmExports' protocol not found")
        }
        guard exportsProtocol.associatedTypes.isEmpty else {
            throw ValidationError("'WasmExports' protocol cannot have associated types")
        }
        guard exportsProtocol.unresolvedInheritedTypes.isEmpty else {
            throw ValidationError("'WasmExports' protocol cannot have inherited types")
        }
        guard exportsProtocol.functionRequirements.allSatisfy({ f in
            f.isStatic && !f.isAsync && !f.isReasync
        }) else {
            throw ValidationError("all requirements should be static and not be async")
        }

        // generate

        if let swift_out = swift_out {
            try GenerateSwift(
                exportsProtocol: exportsProtocol,
                outDirectory: swift_out
            ).run()
        }

        if let ts_out = ts_out {
            try GenerateTS(
                moduleName: moduleName,
                exportsProtocol: exportsProtocol,
                outDirectory: ts_out
            ).run()
        }
    }
}

extension Sequence {
    func eachPairs() -> AnySequence<(Element, Element)> {
        AnySequence(
            zip(self, self.dropFirst())
        )
    }
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self = URL(fileURLWithPath: argument)
    }
}
