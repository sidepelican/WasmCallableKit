import Foundation
import SwiftTypeReader

struct GenerateSwift {
    var exportsProtocol: ProtocolType
    var outDirectory: URL

    func run() throws {
        let content = """
import Foundation

\(exportsProtocol.functionRequirements.contains(where: { !$0.hasOutput }) ? "private let emptyReturnData = Data(\"{}\".utf8)" : "")

\(exportsProtocol.functionRequirements.compactMap({ f in
if f.parameters.isEmpty { return nil }
return """
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
        \(!f.parameters.isEmpty ? "let a = try decoder.decode(\(f.name)Arguments.self, from: arg)" : "")
        \(f.hasOutput ? "let b = " : "")\(f.isThrows ? "try ": "")T.\(f.name)(
\(f.parameters.enumerated().map({ """
            \($0.element.label ?? $0.element.name): a._\($0.offset)
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

extension FunctionRequirement {
    var hasOutput: Bool {
        unresolvedOutputType != nil
    }
}
