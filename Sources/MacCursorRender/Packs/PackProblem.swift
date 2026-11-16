/// One thing wrong with a style pack, in words its author can act on.
/// Problems are collected and reported together; they are never thrown past the loader.
public struct PackProblem: Error, Equatable, Sendable, CustomStringConvertible {
    /// The file inside the pack: "style.json", "art.svg", or "" for the pack as a whole.
    public let file: String
    /// The key path or element, already quoted, e.g. `"tail.leg.width"` or `element "pads"`.
    public let location: String
    public let message: String

    public init(file: String, location: String = "", _ message: String) {
        self.file = file
        self.location = location
        self.message = message
    }

    /// `art.svg: element "pads" not found`.
    public var description: String {
        let head = file.isEmpty ? "" : "\(file): "
        return head + (location.isEmpty ? message : "\(location) \(message)")
    }

    /// The same, prefixed with the pack's folder or file name, as shown to users.
    public func described(in pack: String) -> String {
        file.isEmpty ? "\(pack): \(description)" : "\(pack)/\(description)"
    }
}
