@testable import CodableToTypeScript
import Foundation
import SwiftTypeReader
import TSCodeModule

struct GenerateTS {
    var exportsProtocol: ProtocolType
    var outDirectory: URL

    private let typeMap: TypeMap = {
        var typeMapTable: [String: String] = TypeMap.defaultTable
        typeMapTable["URL"] = "string"
        typeMapTable["Date"] = "number"
        return TypeMap(table: typeMapTable)
    }()

    func run() throws {
        var content = """
type PartialSwiftRuntime = {
  callSwiftFunction(functionID: number, argument: any): any
}

export type CallableKitExports = {
\(try exportsProtocol.functionRequirements.map({ f in
"""
  \(f.name): (\(try f.parameters.map({ "\($0.name): \(try typeMap.tsName(stype: $0.type()))" }).joined(separator: ", "))) => \(try f.outputType().map(typeMap.tsName(stype:)) ?? "void"),
""" }).joined(separator: "\n"))
};

export const bindCallableKitExports = (swift: PartialSwiftRuntime): CallableKitExports => {
  return {
\(try exportsProtocol.functionRequirements.enumerated().map({ (i, f) in
"""
    \(f.name): (\(try f.parameters.map({ "\($0.name): \(try typeMap.tsName(stype: $0.type()))" }).joined(separator: ", "))): \(try f.outputType().map(typeMap.tsName(stype:)) ?? "void") => swift.callSwiftFunction(\(i), {
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

        for stype in exportsProtocol.module!.types {
            if stype.struct != nil || (stype.enum != nil && !stype.enum!.caseElements.isEmpty) {
                let tsCode = try CodableToTypeScript.CodeGenerator(
                    typeMap: typeMap,
                    standardTypes: CodableToTypeScript.CodeGenerator.defaultStandardTypes
                )(type: stype)

                let tsDecls = tsCode.decls.filter {
                    if case .importDecl = $0 { return false } else { return true }
                }
                    .map { $0.description.trimmingCharacters(in: .whitespacesAndNewlines) }
                content.append("\n\n")
                content.append(tsDecls.joined(separator: "\n\n"))
            }
        }

        try content.data(using: .utf8)!
            .write(to: outDirectory.appendingPathComponent("CallableKitExports.ts"), options: .atomic)

        if let resourceURL = Bundle.module.resourceURL.map({ $0.appendingPathComponent("templates") }) {
            do {
                let templates = try FileManager.default.contentsOfDirectory(atPath: resourceURL.path)
                for template in templates {
                    try? FileManager.default.removeItem(at: outDirectory.appendingPathComponent(template))
                    try FileManager.default.copyItem(
                        at: resourceURL.appendingPathComponent(template),
                        to: outDirectory.appendingPathComponent(template)
                    )
                }
            } catch {
                print(error)
            }
        }
    }
}

extension TypeMap {
    fileprivate func tsName(stype: SType) throws -> String {
        let printer = PrettyPrinter()
        try StructConverter.transpile(typeMap: self, type: stype).print(printer: printer)
        return printer.output
    }
}

fileprivate func unwrapGenerics(typeName: String) -> [String] {
    typeName
        .components(separatedBy: .whitespaces.union(.init(charactersIn: "<>,")))
        .filter { !$0.isEmpty }
}

fileprivate func findTypes(in tsType: TSType) -> [String] {
    switch tsType {
    case .array(let array):
        return findTypes(in: array.element)
    case .dictionary(let dictionary):
        return findTypes(in: dictionary.element)
    case .named(let named):
        return [named.name]
    case .record(let record):
        return record.fields.flatMap { findTypes(in: $0.type) }
    case .stringLiteral:
        return []
    case .union(let union):
        return union.items.flatMap { findTypes(in: $0) }
    }
}
