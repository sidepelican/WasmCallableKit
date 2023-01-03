import CWasmCallableKit
import Foundation

public struct InstanceID: RawRepresentable, Hashable {
    public init(_ value: CInt) {
        self.rawValue = value
    }
    public init?(rawValue: CInt) {
        self.rawValue = rawValue
    }
    public var rawValue: CInt
}

public protocol ClassMetadataProtocol<C> {
    associatedtype C: AnyObject
    var inits: [(Data) throws -> C] { get }
    var methods: [(C, Data) throws -> Data] { get }
    func initAndBind(initializerID: Int, argData: Data) throws -> any ClassBindingProtocol
}

public struct ClassMetadata<C: AnyObject>: ClassMetadataProtocol {
    public init() {}
    public var inits: [(Data) throws -> C] = []
    public var methods: [(C, Data) throws -> Data] = []

    public func initAndBind(initializerID: Int, argData: Data) throws -> any ClassBindingProtocol {
        let `init` = inits[initializerID]
        return Binding(
            instance: try `init`(argData),
            metadata: self
        )
    }
}

public protocol ClassBindingProtocol<C> {
    associatedtype C: AnyObject
    func send(functionID: Int, argData: Data) throws -> Data
}

private struct Binding<C: AnyObject>: ClassBindingProtocol {
    var instance: C
    var metadata: ClassMetadata<C>

    func send(functionID: Int, argData: Data) throws -> Data {
        try metadata.methods[functionID](instance, argData)
    }
}

private var bindings: [InstanceID: any ClassBindingProtocol] = [:]
private var classMetadata: [any ClassMetadataProtocol] = []
private var lastInstanceID: InstanceID.RawValue = 0
private func takeInstanceID() -> InstanceID {
    defer { lastInstanceID += 1 }
    return .init(lastInstanceID)
}

extension WasmCallableKit {
    public static func registerClassMetadata(meta: [any ClassMetadataProtocol]) {
        classMetadata = meta
    }
}

@_cdecl("ck_class_init_impl")
func ck_class_init_impl(_ classID: CInt, _ initilizerID: CInt, _ argumentBufferLength: CInt) -> CInt {
    let metadata = classMetadata[Int(classID)]

    let memory = malloc(Int(argumentBufferLength)).assumingMemoryBound(to: UInt8.self)
    defer { memory.deallocate() }
    receive_arg(memory)

    let arg = Data(String(decodingCString: memory, as: UTF8.self).utf8)
    do {
        let binding = try metadata.initAndBind(initializerID: Int(initilizerID), argData: arg)
        let instanceID = takeInstanceID()
        bindings[instanceID] = binding
        return instanceID.rawValue
    } catch {
        var message = "\(error)"
        message.withUTF8 { (p: UnsafeBufferPointer<UInt8>) in
            write_ret(p.baseAddress!, numericCast(p.count))
        }
        return -1;
    }
}

@_cdecl("ck_class_send_impl")
func ck_class_send_impl(_ instanceID: CInt, _ functionID: CInt, _ argumentBufferLength: CInt) -> CInt {
    guard let binding = bindings[InstanceID(instanceID)] else {
        fatalError("TODO:")
    }

    let memory = malloc(Int(argumentBufferLength)).assumingMemoryBound(to: UInt8.self)
    defer { memory.deallocate() }
    receive_arg(memory)

    let arg = Data(String(decodingCString: memory, as: UTF8.self).utf8)
    do {
        let ret = try binding.send(functionID: Int(functionID), argData: arg)
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
