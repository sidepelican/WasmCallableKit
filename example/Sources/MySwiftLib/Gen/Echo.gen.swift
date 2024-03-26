import WasmCallableKit

func buildEchoMetadata() -> ClassMetadata<Echo> {
    var meta = ClassMetadata<Echo>()
    meta.inits.append { argData in
        struct Params: Decodable {
            var _0: String
        }
        let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
        return Echo(
            name: args._0
        )
    }
    meta.methods.append { `self`, _ in
        let ret = self.hello()
        return try WasmCallableKit.encodeJSON(ret)
    }
    meta.methods.append { `self`, _ in
        let _ = self.sayHello()
        return []
    }
    meta.methods.append { `self`, argData in
        struct Params: Decodable {
            var _0: Echo.UpdateKind
        }
        let args = try WasmCallableKit.decodeJSON(Params.self, from: argData)
        let _ = self.update(
            args._0
        )
        return []
    }
    return meta
}