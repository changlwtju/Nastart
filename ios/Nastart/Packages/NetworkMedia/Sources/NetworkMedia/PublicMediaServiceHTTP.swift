import Foundation
#if canImport(Security)
import Security
#endif

/// Isolated public-only metadata requests. Never attach app cookies, credentials or redirect targets.
public struct PublicMediaServiceHTTP: PublicMediaServiceTransport {
    private let certificates: [String: Data]
    /// Reuse only certificates already approved by the host. Probes never create or rotate trust records.
    public init(trustedCertificates: [URL: Data] = [:]) {
        var values: [String: Data] = [:]
        for (url, data) in trustedCertificates where url.scheme?.lowercased() == "https" {
            guard (try? MediaServiceEndpoint(url)) != nil else { continue }
            values[publicMediaOrigin(url)] = data
        }
        certificates = values
    }
    public func send(_ request: URLRequest) async throws -> PublicMediaServiceResponse {
        guard request.httpMethod == "GET", let url = request.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil, url.fragment == nil, request.httpBody == nil,
              (request.allHTTPHeaderFields ?? [:]).keys.allSatisfy({ $0.lowercased() == "accept" }) else { throw NetworkMediaError.invalidAddress }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard query.allSatisfy({ ["v", "c", "f"].contains($0.name) }) else { throw NetworkMediaError.invalidAddress }
        let operation = MediaServiceReadRequest(request, certificate: certificates[publicMediaOrigin(url)])
        return try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
    }
}

final class MediaServiceReadRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let request: URLRequest
    private let certificate: Data?
    private let lock = NSLock()
    private var cancelled = false
    private var continuation: CheckedContinuation<PublicMediaServiceResponse, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var status = 0
    private var failure: Error?
    private var authenticationRejected = false
    private let limit: Int
    private let deadline: TimeInterval
    init(_ request: URLRequest, certificate: Data?, limit: Int = 128 * 1024, deadline: TimeInterval = 3) {
        self.request = request; self.certificate = certificate; self.limit = limit; self.deadline = deadline
    }
    func run() async throws -> PublicMediaServiceResponse {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
            self.continuation = continuation
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForResource = deadline; config.timeoutIntervalForRequest = min(3, deadline)
            config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
            config.httpShouldSetCookies = false
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            let task = session.dataTask(with: request); self.task = task
            lock.unlock(); task.resume()
        }
    }
    func cancel() { lock.lock(); cancelled = true; let task = task; lock.unlock(); task?.cancel() }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else { failure = NetworkMediaError.invalidResponse; completionHandler(.cancel); return }
        status = http.statusCode
        guard http.expectedContentLength <= Int64(limit) else { failure = NetworkMediaError.responseTooLarge; completionHandler(.cancel); return }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard buffer.count + data.count <= limit else { failure = NetworkMediaError.responseTooLarge; dataTask.cancel(); return }
        buffer.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        status = response.statusCode; completionHandler(nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM, NSURLAuthenticationMethodNegotiate].contains(challenge.protectionSpace.authenticationMethod) {
            authenticationRejected = true; completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            #if canImport(Security)
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let certificate, let url = request.url,
               challenge.protectionSpace.host.caseInsensitiveCompare(url.host ?? "") == .orderedSame,
               challenge.protectionSpace.port == (url.port ?? 443), let trust = challenge.protectionSpace.serverTrust,
               let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let leaf = chain.first,
               SecCertificateCopyData(leaf) as Data == certificate {
                completionHandler(.useCredential, URLCredential(trust: trust)); return
            }
            #endif
            completionHandler(.performDefaultHandling, nil)
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let continuation = continuation; self.continuation = nil
        let wasCancelled = cancelled; self.task = nil; self.session = nil; lock.unlock()
        session.invalidateAndCancel()
        if wasCancelled { continuation?.resume(throwing: CancellationError()) }
        else if authenticationRejected { continuation?.resume(returning: .init(statusCode: 401, data: Data())) }
        else if let error = failure ?? error { continuation?.resume(throwing: error) }
        else { continuation?.resume(returning: .init(statusCode: status, data: buffer)) }
    }
}

private func publicMediaOrigin(_ url: URL) -> String {
    (url.scheme?.lowercased() ?? "") + "://" + (url.host?.lowercased() ?? "") + ":" + String(url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80))
}
