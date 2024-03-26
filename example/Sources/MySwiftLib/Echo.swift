public class Echo {
    private var name: String
    public init(name: String) {
        self.name = name
    }

    private var helloMessage: String {
        "Hello, \(name)!"
    }

    public func hello() -> String {
        helloMessage
    }

    public func sayHello() {
        print(helloMessage)
    }

    public enum UpdateKind: Decodable {
        case name(String)
    }

    public func update(_ update: UpdateKind) {
        switch update {
        case .name(let name):
            self.name = name
        }
    }

    deinit {
        print("Echo deinit")
    }
}
