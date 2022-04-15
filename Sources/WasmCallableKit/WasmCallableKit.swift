import CWasmCallableKit
import Foundation

private var functionList: [(Data) throws -> Data]!

public enum WasmCallableKit {
    public static func setFunctionList(_ functions: [(Data) throws -> Data]) {
        functionList = functions
    }
}

@_cdecl("ck_send_impl")
func ck_send_impl(_ functionID: Int32, _ argumentBufferLength: Int32) -> Int32 {
    // +1 for null terminator
    let memory = malloc(Int(argumentBufferLength) + 1).assumingMemoryBound(to: UInt8.self)
    defer { memory.deallocate() }
    receive_arg(memory)

    let arg = Data(String(decodingCString: memory, as: UTF8.self).utf8)
    do {
        let ret = try functionList[Int(functionID)](arg)
        ret.withUnsafeBytes { (p: UnsafeRawBufferPointer) in
            write_ret(p.baseAddress!, Int32(p.count))
        }
        return 0;
    } catch {
        var message = "\(error)"
        message.withUTF8 { (p: UnsafeBufferPointer<UInt8>) in
            write_ret(p.baseAddress!, Int32(p.count))
        }
        return 1;
    }
}
