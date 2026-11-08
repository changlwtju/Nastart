import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

public protocol WebDAVTransport: Sendable {
    func propfind(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data
}
public protocol WebDAVMetadataTransport: WebDAVTransport {
    func readNFO(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data
}
public protocol WebDAVArtworkTransport: WebDAVTransport {
    func readArtwork(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data
}

public struct WebDAVClient: ReadOnlyMetadataSource, ReadOnlyArtworkSource, Sendable {
    let scope: WebDAVScope
    let credential: WebDAVCredential?
    let transport: any WebDAVTransport
    public init(scope: WebDAVScope, credential: WebDAVCredential? = nil, transport: any WebDAVTransport = BoundedWebDAVTransport()) {
        self.scope = scope; self.credential = credential; self.transport = transport
    }
    public func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
        try Task.checkCancellation()
        var request = URLRequest(url: scope.directoryURL(directory))
        request.httpMethod = "PROPFIND"
        request.timeoutInterval = 20
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.httpBody = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/><d:getlastmodified/><d:getetag/></d:prop></d:propfind>
        """.utf8)
        let data = try await transport.propfind(request, credential: credential)
        try Task.checkCancellation()
        return try DAVListingParser.parse(data, scope: scope, requested: directory)
    }
    public func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data {
        try Task.checkCancellation()
        guard path.isWithin(root), path != root, (path.name as NSString).pathExtension.lowercased() == "nfo",
              let metadataTransport = transport as? any WebDAVMetadataTransport else { throw NetworkMediaError.outsideRoot }
        var request = URLRequest(url: scope.fileURL(path))
        request.httpMethod = "GET"; request.timeoutInterval = 20
        request.setValue("application/xml, text/xml, text/plain", forHTTPHeaderField: "Accept")
        let data = try await metadataTransport.readNFO(request, credential: credential)
        try Task.checkCancellation()
        guard data.count <= NFOReader.maxBytes else { throw NetworkMediaError.responseTooLarge }
        return data
    }
    public func readArtwork(_ reference: LocalArtworkReference, root: DAVPath) async throws -> Data {
        try Task.checkCancellation()
        guard reference.isValid(root: root), let reader = transport as? any WebDAVArtworkTransport else {
            throw NetworkMediaError.outsideRoot
        }
        var request = URLRequest(url: scope.fileURL(reference.path))
        request.httpMethod = "GET"; request.timeoutInterval = 20
        request.setValue("image/jpeg, image/png", forHTTPHeaderField: "Accept")
        if let etag = reference.etag, !etag.isEmpty, !etag.hasPrefix("W/") {
            guard etag.utf8.count <= 1024, !etag.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { throw NetworkMediaError.invalidArtwork }
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        }
        let data = try await reader.readArtwork(request, credential: credential)
        try Task.checkCancellation()
        guard data.count <= LocalArtworkReference.maximumBytes,
              reference.size.map({ $0 == Int64(data.count) }) ?? true else { throw NetworkMediaError.invalidArtwork }
        return data
    }
}

/// Each call has its own bounded task/session. No write method or redirect is forwarded.
public struct BoundedWebDAVTransport: WebDAVMetadataTransport, WebDAVArtworkTransport {
    public init() {}
    public func propfind(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data {
        guard request.httpMethod == "PROPFIND", request.value(forHTTPHeaderField: "Depth") == "1" else { throw NetworkMediaError.invalidResponse }
        let operation = DAVRequestOperation(request: request, credential: credential)
        return try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
    }
    public func readNFO(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data {
        guard request.httpMethod == "GET", let url = request.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.pathExtension.lowercased() == "nfo", request.httpBody == nil else { throw NetworkMediaError.outsideRoot }
        let operation = DAVRequestOperation(request: request, credential: credential, limit: NFOReader.maxBytes, status: 200)
        return try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
    }
    public func readArtwork(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data {
        guard request.httpMethod == "GET", let url = request.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              LocalArtworkReference.isSupported(url.lastPathComponent), request.httpBody == nil else { throw NetworkMediaError.outsideRoot }
        let operation = DAVRequestOperation(request: request, credential: credential, limit: LocalArtworkReference.maximumBytes, status: 200)
        return try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
    }
}

/// One playback's connection pool. Reusing it avoids a TCP handshake and an authentication
/// round trip per window, which dominated reads over a slow route. It dies with its reader.
final class DAVPlaybackTransport: @unchecked Sendable {
    let session: URLSession
    private let lock = NSLock()
    private var acceptsBasic = false
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 25
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        session = URLSession(configuration: config)
    }
    deinit { session.invalidateAndCancel() }
    /// Set only after this server asked for Basic, so a Digest server never receives Basic credentials.
    var sendsBasicUpFront: Bool {
        get { lock.lock(); defer { lock.unlock() }; return acceptsBasic }
        set { lock.lock(); acceptsBasic = newValue; lock.unlock() }
    }
}

final class DAVRequestOperation: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let request: URLRequest
    let credential: WebDAVCredential?
    private let transport: DAVPlaybackTransport?
    let limit: Int
    let status: Int
    let allowsSelfSignedCertificates: Bool
    let validateResponse: (@Sendable (HTTPURLResponse) throws -> Void)?
    let exactBodyLength: Int?
    private let lock = NSLock()
    private var cancelled = false
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var failure: Error?
    init(request: URLRequest, credential: WebDAVCredential?, limit: Int = 4 * 1024 * 1024, status: Int = 207, allowsSelfSignedCertificates: Bool = false,
         exactBodyLength: Int? = nil, transport: DAVPlaybackTransport? = nil, validateResponse: (@Sendable (HTTPURLResponse) throws -> Void)? = nil) {
        self.transport = transport
        self.request = request; self.credential = credential; self.limit = limit; self.status = status; self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.exactBodyLength = exactBodyLength; self.validateResponse = validateResponse
    }
    func run() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
            self.continuation = continuation
            if let transport {
                var shared = request
                if transport.sendsBasicUpFront, let credential {
                    shared.setValue("Basic " + Data((credential.username + ":" + credential.password).utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
                }
                let task = transport.session.dataTask(with: shared); task.delegate = self; self.task = task
                lock.unlock(); task.resume()
                return
            }
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForResource = 25
            config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            let task = session.dataTask(with: request); self.task = task
            lock.unlock(); task.resume()
        }
    }
    func cancel() { lock.lock(); cancelled = true; let task = task; lock.unlock(); task?.cancel() }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse else { failure = NetworkMediaError.invalidResponse; completionHandler(.cancel); return }
        guard response.statusCode == status else {
            if failure == nil { failure = (300..<400).contains(response.statusCode) ? NetworkMediaError.redirect : NetworkMediaError.http(response.statusCode) }
            completionHandler(.cancel); return
        }
        do { try validateResponse?(response) }
        catch { failure = error; completionHandler(.cancel); return }
        guard response.expectedContentLength <= Int64(limit) else { failure = NetworkMediaError.responseTooLarge; completionHandler(.cancel); return }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard buffer.count + data.count <= limit else { failure = NetworkMediaError.responseTooLarge; dataTask.cancel(); return }
        buffer.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        failure = NetworkMediaError.redirect; completionHandler(nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace, url = request.url!
        if [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest].contains(space.authenticationMethod) {
            guard challenge.previousFailureCount == 0, space.host.lowercased() == url.host?.lowercased(),
                  space.port == (url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)), let credential else {
                // Foundation reports a cancelled challenge as a URL error on some
                // OS versions. Preserve the server's authentication failure instead.
                if failure == nil { failure = NetworkMediaError.http(401) }
                completionHandler(.cancelAuthenticationChallenge, nil); return
            }
            if space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic { transport?.sendsBasicUpFront = true }
            completionHandler(.useCredential, URLCredential(user: credential.username, password: credential.password, persistence: .none))
        } else {
            #if canImport(Security)
            if space.authenticationMethod == NSURLAuthenticationMethodServerTrust, allowsSelfSignedCertificates,
               space.host.lowercased() == url.host?.lowercased(), space.port == (url.port ?? 443), let trust = space.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust)); return
            }
            #endif
            completionHandler(.performDefaultHandling, nil)
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let continuation = continuation; self.continuation = nil
        let wasCancelled = cancelled; self.task = nil; self.session = nil; lock.unlock()
        if transport == nil { session.invalidateAndCancel() }
        if wasCancelled { continuation?.resume(throwing: CancellationError()) }
        else if let error = failure ?? error { continuation?.resume(throwing: error) }
        else if let exactBodyLength, buffer.count != exactBodyLength { continuation?.resume(throwing: NetworkMediaPlaybackError.invalidRangeResponse) }
        else { continuation?.resume(returning: buffer) }
    }
}

enum DAVListingParser {
    static func parse(_ data: Data, scope: WebDAVScope, requested: DAVPath) throws -> [RemoteMediaEntry] {
        guard data.count <= 4 * 1024 * 1024, let text = String(data: data, encoding: .utf8),
              !text.uppercased().contains("<!DOCTYPE"), !text.uppercased().contains("<!ENTITY") else { throw NetworkMediaError.invalidResponse }
        let delegate = ListingDelegate()
        let parser = XMLParser(data: data); parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), delegate.validRoot, !delegate.failed else { throw NetworkMediaError.invalidResponse }
        var result: [RemoteMediaEntry] = [], keys = Set<String>(), sawSelf = false
        for response in delegate.responses {
            guard let href = response.href, !response.badStatus, let directory = response.directory else { throw NetworkMediaError.incompleteListing }
            let path = try scope.resolve(href: href, requested: requested)
            guard keys.insert(path.key).inserted else { throw NetworkMediaError.invalidResponse }
            if path == requested { guard directory else { throw NetworkMediaError.incompleteListing }; sawSelf = true; continue }
            result.append(RemoteMediaEntry(path: path, isDirectory: directory, size: response.size, modified: response.modified, etag: response.etag))
        }
        guard sawSelf else { throw NetworkMediaError.incompleteListing }
        return result.sorted { $0.isDirectory != $1.isDirectory ? $0.isDirectory : $0.path.name.localizedStandardCompare($1.path.name) == .orderedAscending }
    }
}

private final class ListingDelegate: NSObject, XMLParserDelegate {
    struct Response { var href: String?; var directory: Bool?; var size: Int64?; var modified: String?; var etag: String?; var badStatus = false }
    var responses: [Response] = []
    var validRoot = false, failed = false
    private var stack: [String] = [], texts: [String] = []
    private var response: Response?
    private var properties: [String: String] = [:]
    private var propertyStatus: Int?, responseStatus: Int?
    private var isCollection = false, hasType = false
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let key = namespaceURI == "DAV:" ? name : "foreign"
        if stack.isEmpty { validRoot = key == "multistatus" }
        stack.append(key); texts.append("")
        if stack.count > 64 || responses.count >= 20_000 { failed = true; parser.abortParsing(); return }
        if key == "response", stack.count == 2 { response = Response(); responseStatus = nil }
        if key == "propstat" { properties = [:]; propertyStatus = nil; isCollection = false; hasType = false }
        if key == "resourcetype", stack.suffix(3) == ["propstat", "prop", "resourcetype"] { hasType = true }
        if key == "collection", stack.suffix(2) == ["resourcetype", "collection"] { isCollection = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !texts.isEmpty else { return }
        texts[texts.count - 1] += string
        if texts[texts.count - 1].utf8.count > 65_536 { failed = true; parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard let key = stack.last, let text = texts.last?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        let parent = stack.dropLast().last
        if key == "href", parent == "response" { response?.href = text }
        if key == "status" {
            let status = text.split(separator: " ").dropFirst().first.flatMap { Int($0) }
            if parent == "propstat" { propertyStatus = status } else if parent == "response" { responseStatus = status }
        }
        if parent == "prop", key != "foreign" { properties[key] = text }
        if key == "propstat", propertyStatus == 200 {
            if hasType { response?.directory = isCollection }
            if let size = properties["getcontentlength"].flatMap(Int64.init), size >= 0 { response?.size = size }
            if let modified = properties["getlastmodified"] { response?.modified = modified }
            if let etag = properties["getetag"] { response?.etag = etag }
        }
        if key == "response", stack.count == 2, var item = response {
            item.badStatus = responseStatus.map { !(200..<300).contains($0) } ?? false
            responses.append(item); response = nil
        }
        stack.removeLast(); texts.removeLast()
    }
}
