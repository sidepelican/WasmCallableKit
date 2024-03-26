import CWasmCallableKit

private var functionList: [([UInt8]) throws -> [UInt8]]!

public enum WasmCallableKit {
    public static func setFunctionList(_ functions: [([UInt8]) throws -> [UInt8]]) {
        functionList = functions
    }
}

@_cdecl("ck_send_impl")
func ck_send_impl(_ functionID: CInt, _ argumentBufferLength: CInt) -> CInt {
    let arg = consumeArgumentBuffer(argumentBufferLength)

    do {
        let ret = try functionList[Int(functionID)](arg)
        ret.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
            write_ret(p.baseAddress!, numericCast(p.count))
        }
        return 0;
    } catch {
        var message = "\(error)"
        message.withUTF8 { (p: UnsafeBufferPointer<UInt8>) in
            write_ret(p.baseAddress!, numericCast(p.count))
        }
        return -1;
    }
}

func consumeArgumentBuffer(_ argumentBufferLength: CInt) -> [UInt8] {
    var arg = Array<UInt8>(repeating: 0, count: Int(argumentBufferLength))
    arg.withUnsafeMutableBufferPointer { p in
        receive_arg(p.baseAddress!)
    }
    arg.removeLast() // remove null terminator
    return arg
}
