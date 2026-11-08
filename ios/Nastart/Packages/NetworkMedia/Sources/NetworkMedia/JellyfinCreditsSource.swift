import Foundation
import CryptoKit

/// Artwork already held by an explicitly authenticated media server. NFO URLs
/// are never followed and names alone never establish a film match.
public struct MediaCredit: Equatable, Sendable {
    public let name: String
    public let role: String
    public let imageID: String?
    public let imageTag: String?
}
public struct JellyfinCreditsSource: Sendable {
    public let identity: String
    private let endpoint: URL
    private let userID: String
    private let token: String
    private let transport: @Sendable (URLRequest, Int) async throws -> PublicMediaServiceResponse
    public init(endpoint: URL, userID: String, token: String, trustedCertificate: Data? = nil) throws {
        self = try Self(endpoint: endpoint, userID: userID, token: token) { request, limit in
            let operation = MediaServiceReadRequest(request, certificate: trustedCertificate, limit: limit, deadline: 6)
            return try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
        }
    }
    init(endpoint: URL, userID: String, token: String,
         transport: @escaping @Sendable (URLRequest, Int) async throws -> PublicMediaServiceResponse) throws {
        _ = try MediaServiceEndpoint(endpoint)
        guard Self.identifier(userID), !token.isEmpty, token.count <= 8192,
              !token.contains(where: { $0.isNewline || $0 == "\0" }) else { throw NetworkMediaError.invalidAddress }
        self.endpoint = endpoint; self.userID = userID; self.token = token; self.transport = transport
        identity = SHA256.hash(data: Data((endpoint.absoluteString + "|" + userID + "|" + token).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 128 && value.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
    }
    private static func providers(_ ids: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in ids {
            let key = key.lowercased(), value = value.lowercased()
            guard value.count <= 64 else { continue }
            if key == "tmdb", !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) { if let old = result[key], old != value { return [:] }; result[key] = value }
            if key == "imdb", value.hasPrefix("tt"), value.count > 2, value.dropFirst(2).allSatisfy({ $0.isASCII && $0.isNumber }) { if let old = result[key], old != value { return [:] }; result[key] = value }
        }
        return result
    }
    private func request(_ path: [String], query: [URLQueryItem] = []) -> URLRequest {
        var parts = URLComponents(url: path.reduce(endpoint) { $0.appendingPathComponent($1) }, resolvingAgainstBaseURL: false)!
        parts.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: parts.url!); request.httpMethod = "GET"; request.timeoutInterval = 6
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    private func read(_ request: URLRequest, limit: Int) async throws -> Data {
        try Task.checkCancellation()
        let response = try await transport(request, limit)
        try Task.checkCancellation()
        guard response.statusCode == 200, response.data.count <= limit else { throw NetworkMediaError.invalidResponse }
        return response.data
    }
    public func people(for metadata: LocalMediaMetadata) async throws -> [MediaCredit] {
        // Movie and episode provider identifiers live in different namespaces.
        // Series/episode matching is not guessed from the title or parent ID.
        let expected = Self.providers(metadata.providerIDs)
        guard metadata.kind == .movie, !metadata.title.isEmpty, metadata.title.count <= 512, let provider = ["imdb", "tmdb"].first(where: { expected[$0] != nil }) else { return [] }
        let data = try await read(request(["Users", userID, "Items"], query: [
            .init(name: "SearchTerm", value: metadata.title),
            .init(name: "IncludeItemTypes", value: "Movie"), .init(name: "Recursive", value: "true"),
            .init(name: "Fields", value: "ProviderIds,People"), .init(name: "Limit", value: "20"),
            .init(name: "EnableTotalRecordCount", value: "true"), .init(name: "EnableUserData", value: "false")]), limit: 512 * 1024)
        struct Person: Decodable { let Name: String; let Id: String?; let `Type`: String?; let Role: String?; let PrimaryImageTag: String? }
        struct Item: Decodable { let Id: String; let `Type`: String?; let ProviderIds: [String: String]?; let People: [Person]? }
        struct Page: Decodable { let Items: [Item]; let TotalRecordCount: Int? }
        let page = try JSONDecoder().decode(Page.self, from: data)
        CreditReadDiagnostics.record("candidates", ["items": String(page.Items.count), "total": String(page.TotalRecordCount ?? -1)])
        // Search only narrows a bounded candidate page. A title is never proof:
        // require a complete page and exactly one independently verified ID match.
        guard page.TotalRecordCount == page.Items.count, page.Items.count <= 20 else { return [] }
        let matches = page.Items.filter { movie in
            guard movie.Type == "Movie", Self.identifier(movie.Id) else { return false }
            let actual = Self.providers(movie.ProviderIds ?? [:])
            return actual[provider] == expected[provider]
                && expected.allSatisfy { actual[$0.key] == nil || actual[$0.key] == $0.value }
        }
        CreditReadDiagnostics.record("matches", ["count": String(matches.count)])
        guard matches.count == 1, let movie = matches.first else { return [] }
        var result: [MediaCredit] = []
        let people = movie.People ?? []
        let ordered = people.filter { $0.Type == "Director" } + people.filter { $0.Type != "Director" }
        for person in ordered.prefix(60) {
            guard !person.Name.isEmpty, person.Name.count <= 512,
                  ["Director", "Actor", "Producer", "Writer"].contains(person.Type ?? "") else { continue }
            let role = person.Type == "Director" ? "导演" : person.Type == "Producer" ? "制片" : person.Type == "Writer" ? "编剧" : String((person.Role ?? "演员").prefix(512))
            let id = person.Id.flatMap { Self.identifier($0) ? $0 : nil }
            let tag = person.PrimaryImageTag.flatMap { Self.identifier($0) ? $0 : nil }
            let credit = MediaCredit(name: person.Name, role: role, imageID: id, imageTag: tag)
            if let index = result.firstIndex(where: { $0.imageID != nil && $0.imageID == id }) {
                let old = result[index]
                result[index] = .init(name: old.name, role: old.role == role ? old.role : old.role + " · " + role, imageID: id, imageTag: old.imageTag ?? tag)
            } else { result.append(credit) }
        }
        return result
    }
    public func artwork(for person: MediaCredit) async throws -> Data? {
        guard let id = person.imageID, let tag = person.imageTag, Self.identifier(id), Self.identifier(tag) else { return nil }
        var request = request(["Items", id, "Images", "Primary"], query: [
            .init(name: "maxWidth", value: "320"), .init(name: "quality", value: "88"), .init(name: "tag", value: tag)])
        request.setValue("image/jpeg,image/png", forHTTPHeaderField: "Accept")
        let data = try await CreditImageReads.shared.read { try await read(request, limit: LocalArtworkReference.maximumBytes) }
        try LocalArtworkDecoder.validate(data)
        return data
    }
}

/// Visible credits share a two-request budget; a disappearing shelf cancels
/// both queued permits and its own bounded transfer.
private actor CreditImageReads {
    static let shared = CreditImageReads()
    private var active = 0
    func read(_ operation: @Sendable () async throws -> Data) async throws -> Data {
        while active >= 2 { try await Task.sleep(nanoseconds: 50_000_000) }
        try Task.checkCancellation(); active += 1
        defer { active -= 1 }
        return try await operation()
    }
}
