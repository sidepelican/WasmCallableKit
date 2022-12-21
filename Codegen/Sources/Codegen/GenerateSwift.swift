import Foundation
import SwiftTypeReader

struct GenerateSwift {
    var exportsProtocol: ProtocolType
    var outDirectory: URL

    func run() throws {
        let content = """
import Foundation

\(exportsProtocol.decl.functions.contains(where: { !$0.hasOutput }) ? "private let emptyReturnData = Data(\"{}\".utf8)" : "")

\(exportsProtocol.decl.functions.compactMap({ f in
if f.parameters.isEmpty { return nil }
return """
private struct \(f.name)Arguments: Decodable {
\(f.parameters.enumerated().map({ """
    var _\($0.offset): \($0.element.interfaceType.description)
""" }).joined(separator: "\n"))
}
"""
}).joined(separator: "\n\n"))

private func makeFunctionList<T: WasmExports>(wasmExports: T.Type) -> [(Data) throws -> Data] {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    var ret: [(Data) throws -> Data] = []
\(exportsProtocol.decl.functions.map({ f in
"""
    ret.append { (arg: Data) in
        \(!f.parameters.isEmpty ? "let a = try decoder.decode(\(f.name)Arguments.self, from: arg)" : "")
        \(f.hasOutput ? "let b = " : "")\(f.isThrows ? "try ": "")T.\(f.name)(
\(f.parameters.enumerated().map({ """
            \($0.element.argumentName!): a._\($0.offset)
""" }).joined(separator: ",\n"))
        )
        return \(f.hasOutput ? "try encoder.encode(b)" : "emptyReturnData")
    }
"""
}).joined(separator: "\n"))
    return ret
}

extension WasmExports {
    static var functionList: [(Data) throws -> Data] {
        makeFunctionList(wasmExports: Self.self)
    }
}
"""

        try? FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try content.data(using: .utf8)!
            .write(to: outDirectory.appendingPathComponent("Generated.swift"), options: .atomic)
    }
}

extension FuncDecl {
    var hasOutput: Bool {
        resultTypeRepr != nil
    }

    var isThrows: Bool {
        modifiers.contains(.throws)
    }
}
