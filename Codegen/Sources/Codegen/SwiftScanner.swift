import Foundation
import SwiftTypeReader

struct ScanResult {
    struct ClassInfo {
        var classID: Int
        var decl: ClassDecl
        var inits: [InitDecl]
        var methods: [FuncDecl]
    }

    struct File {
        var source: SourceFile
        var classes: [ClassInfo]
        var url: URL {
            source.file
        }
        var imports: [ImportDecl] {
            source.imports
        }
    }
    var files: [File]

    var globalFuncs: [FuncDecl]
}

enum SwiftScanner {
    static func scan(sources: [SourceFile]) throws -> ScanResult {
        var globalFuncs: [FuncDecl] = []
        var files: [ScanResult.File] = []

        var classIDs = (0...).makeIterator()

        for source in sources {
            let classInfo = source.types
                .compactMap { $0 as? ClassDecl }
                .filter(\.isPublic)
                .compactMap { classDecl -> ScanResult.ClassInfo? in
                    let inits = classDecl.initializers.filter(\.isPublic)
                    let methods = classDecl.functions.filter(\.isPublic)
                    guard !inits.isEmpty, !methods.isEmpty else {
                        return nil
                    }
                    return .init(
                        classID: classIDs.next()!,
                        decl: classDecl,
                        inits: inits,
                        methods: methods
                    )
                }
            if !classInfo.isEmpty {
                files.append(.init(source: source, classes: classInfo))
            }

            globalFuncs.append(contentsOf: source.funcs.filter(\.isPublic))
        }

        return .init(
            files: files.sorted(using: KeyPathComparator(\.url.absoluteString)),
            globalFuncs: globalFuncs
        )
    }
}

extension InitDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension FuncDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension ClassDecl {
    var isPublic: Bool {
        modifiers.contains(.public) || modifiers.contains(.open)
    }
}

extension Bool {
    var not: Bool { !self }
}
