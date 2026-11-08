import Foundation

/// The absolute, slash-delimited UTF-8/TVFS subset of FTP pathnames.
/// FTP command arguments are literal names, never URL-percent-decoded DAV paths.
/// This value checks lexical scope only; it cannot prove server-side containment.
public struct FTPPath: Codable, Hashable, Sendable {
    public enum ValidationError: Error { case invalidPath, limitExceeded }
    public static let maximumDepth = 64
    public static let maximumUTF8Bytes = 8192
    public let components: [String]

    public init(_ absolutePath: String = "/") throws {
        guard absolutePath.hasPrefix("/") else { throw ValidationError.invalidPath }
        guard absolutePath.utf8.count <= Self.maximumUTF8Bytes + 1 else { throw ValidationError.limitExceeded }
        if absolutePath == "/" { try self.init(components: []); return }
        var path = absolutePath.dropFirst()
        if path.hasSuffix("/") { path = path.dropLast() }
        try self.init(components: path.split(separator: "/", omittingEmptySubsequences: false).map(String.init))
    }

    private init(components: [String]) throws {
        guard components.count <= Self.maximumDepth else { throw ValidationError.limitExceeded }
        var bytes = 1 // Leading slash, also the complete root pathname.
        for component in components {
            guard !component.isEmpty, component != ".", component != "..",
                  !component.contains("/"), !component.contains("\\"),
                  !component.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            else { throw ValidationError.invalidPath }
            bytes += component.utf8.count + 1
            guard bytes - 1 <= Self.maximumUTF8Bytes else { throw ValidationError.limitExceeded }
        }
        self.components = components
    }

    public var commandArgument: String { "/" + components.joined(separator: "/") }
    public var name: String { components.last ?? "" }
    /// Byte identity matters on FTP servers that distinguish Unicode spellings.
    public var key: String { Data(commandArgument.utf8).base64EncodedString() }
    public var parent: FTPPath? {
        guard !components.isEmpty else { return nil }
        return try? FTPPath(components: Array(components.dropLast()))
    }
    public func appending(name: String) throws -> FTPPath {
        try FTPPath(components: components + [name])
    }
    public func contains(_ candidate: FTPPath) -> Bool {
        guard components.count <= candidate.components.count else { return false }
        return zip(components, candidate.components).allSatisfy { Data($0.utf8) == Data($1.utf8) }
    }
    public static func == (lhs: FTPPath, rhs: FTPPath) -> Bool {
        Data(lhs.commandArgument.utf8) == Data(rhs.commandArgument.utf8)
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(Data(commandArgument.utf8)) }

    private enum CodingKeys: String, CodingKey { case components }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self).decode([String].self, forKey: .components)
        try self.init(components: values)
    }
}
