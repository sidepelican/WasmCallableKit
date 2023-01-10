struct MessageError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) {
        self.description = description
    }
}
