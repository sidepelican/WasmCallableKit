import Foundation
import SwiftTypeReader

struct GenerateTS {
    var exportsProtocol: ProtocolType
    var outDirectory: URL

    func run() throws {
        let content = """
type PartialSwiftRuntime = {
  callSwiftFunction(functionID: number, argument: any): any
}

export type CallableKitExports = {
\(exportsProtocol.functionRequirements.map({ f in
"""
  \(f.name): (\(f.parameters.map({ "\($0.name): \($0.unresolvedType.name)" }).joined(separator: ", "))) => \(f.unresolvedOutputType?.name ?? "void"),
""" }).joined(separator: "\n"))
};

export const bindCallableKitExports = (swift: PartialSwiftRuntime): CallableKitExports => {
  return {
\(exportsProtocol.functionRequirements.enumerated().map({ (i, f) in
"""
    \(f.name): (\(f.parameters.map({ "\($0.name): \($0.unresolvedType.name)" }).joined(separator: ", "))): \(f.unresolvedOutputType?.name ?? "void") => swift.callSwiftFunction(\(i), {
\(f.parameters.enumerated().map({ i, p in
"""
      _\(i): \(p.name),
"""
}).joined(separator: "\n"))
    }),
""" }).joined(separator: "\n"))
  };
};
"""
        try content.data(using: .utf8)!
            .write(to: outDirectory.appendingPathComponent("CallableKitExports.ts"), options: .atomic)
    }
}
