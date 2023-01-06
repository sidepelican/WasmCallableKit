import WasmCallableKit

extension WasmCallableKit {
    static func install() {
        setFunctionList(buildGlobals())
        registerClassMetadata(meta: [
            buildClassInfo(classID: 0, decl: SwiftTypeReader.ClassDecl, inits: [SwiftTypeReader.InitDecl], methods: [SwiftTypeReader.FuncDecl, SwiftTypeReader.FuncDecl, SwiftTypeReader.FuncDecl])Medadata(),
        ])
    }
}