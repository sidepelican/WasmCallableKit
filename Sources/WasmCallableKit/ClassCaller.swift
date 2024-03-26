import CWasmCallableKit

public struct InstanceID: RawRepresentable, Hashable, CustomStringConvertible {
    public init(_ value: CInt) {
        self.rawValue = value
    }
    public init?(rawValue: CInt) {
        self.rawValue = rawValue
    }
    public var rawValue: CInt
    public var description: String { rawValue.description }
}

public protocol ClassMetadataProtocol<C> {
    associatedtype C: AnyObject
    var inits: [([UInt8]) throws -> C] { get }
    var methods: [(C, [UInt8]) throws -> [UInt8]] { get }
    func initAndBind(initializerID: Int, argData: [UInt8]) throws -> any ClassBindingProtocol
}

public struct ClassMetadata<C: AnyObject>: ClassMetadataProtocol {
    public init() {}
    public var inits: [([UInt8]) throws -> C] = []
    public var methods: [(C, [UInt8]) throws -> [UInt8]] = []

    public func initAndBind(initializerID: Int, argData: [UInt8]) throws -> any ClassBindingProtocol {
        let `init` = inits[initializerID]
        return Binding(
            instance: try `init`(argData),
            metadata: self
        )
    }
}

public protocol ClassBindingProtocol<C> {
    associatedtype C: AnyObject
    func send(functionID: Int, argData: [UInt8]) throws -> [UInt8]
}

private struct Binding<C: AnyObject>: ClassBindingProtocol {
    var instance: C
    var metadata: ClassMetadata<C>

    func send(functionID: Int, argData: [UInt8]) throws -> [UInt8] {
        try metadata.methods[functionID](instance, argData)
    }
}

private var bindings: [(InstanceID, any ClassBindingProtocol)] = []
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
    let arg = consumeArgumentBuffer(argumentBufferLength)

    let metadata = classMetadata[Int(classID)]
    do {
        let binding = try metadata.initAndBind(initializerID: Int(initilizerID), argData: arg)
        let instanceID = takeInstanceID()
        bindings.append((instanceID, binding))
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
    let arg = consumeArgumentBuffer(argumentBufferLength)

    let instanceID = InstanceID(instanceID)
    guard let binding = bindings.first(where: { $0.0 == instanceID })?.1 else {
        var message = "instanceID=\(instanceID) is not found. all=\(bindings.map(\.0))"
        message.withUTF8 { (p: UnsafeBufferPointer<UInt8>) in
            write_ret(p.baseAddress!, numericCast(p.count))
        }
        return -1;
    }

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

@_cdecl("ck_class_free_impl")
func ck_class_free_impl(_ instanceID: CInt) {
    let instanceID = InstanceID(instanceID)
    if let i = bindings.lastIndex(where: { $0.0 == instanceID }) {
        bindings.remove(at: i)
    }
}
