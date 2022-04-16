import Foundation
import SwiftTypeReader

struct GenerateSwift {
    var exportsProtocol: ProtocolType
    var outDirectory: URL

    func run() throws {
        let content = """
import Foundation

private struct Empty: Codable {}

\(exportsProtocol.functionRequirements.map({ f in
"""
private struct \(f.name)Arguments: Decodable {
\(f.parameters.enumerated().map({ """
    var _\($0.offset): \($0.element.unresolvedType.name)
""" }).joined(separator: "\n"))
}
"""
}).joined(separator: "\n\n"))

private func makeFunctionList<T: WasmExports>(wasmExports: T.Type) -> [(Data) throws -> Data] {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    var ret: [(Data) throws -> Data] = []
\(exportsProtocol.functionRequirements.map({ f in
"""
    ret.append { (arg: Data) in
        let a = try decoder.decode(\(f.name)Arguments.self, from: arg)
        let \(f.hasOutput ? "b" : "_") = \(f.isThrows ? "try ": "")T.\(f.name)(
\(f.parameters.enumerated().map({ """
            \($0.element.label ?? $0.element.name): a._\($0.offset)
""" }).joined(separator: ",\n"))
        )
        return try encoder.encode(\(f.hasOutput ? "b" : "Empty()"))
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

        try content.data(using: .utf8)!
            .write(to: outDirectory.appendingPathComponent("Generated.swift"), options: .atomic)
    }
}

extension FunctionRequirement {
    var hasOutput: Bool {
        unresolvedOutputType != nil
    }
}
