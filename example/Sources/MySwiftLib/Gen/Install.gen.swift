import WasmCallableKit

extension WasmCallableKit {
    static func install() {
        setFunctionList(buildGlobals())
        registerClassMetadata(meta: [
            buildEchoMetadata(),
        ])
    }
}