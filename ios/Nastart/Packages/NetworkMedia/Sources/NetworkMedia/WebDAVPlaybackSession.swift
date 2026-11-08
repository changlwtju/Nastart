#if canImport(Network)
import Foundation
import Network

/// One local, revocable playback URL. Only this session owns the source's
/// credential; the decoder receives a random loopback capability instead.
public final class WebDAVPlaybackSession: @unchecked Sendable {
    private let reader: any NetworkMediaByteReader
    private let queue = DispatchQueue(label: "com.nastart.webdav.playback")
    private let target: String
    private var listener: NWListener?
    private var startup: CheckedContinuation<URL, Error>?
    private var started = false
    private var stopped = false
    private var localPort: UInt16?
    private struct Client {
        let connection: NWConnection
        var task: Task<Void, Never>?
        var idle: DispatchWorkItem?
    }
    private var clients: [UUID: Client] = [:]
    private static let maximumClients = 4

    public convenience init(resource: WebDAVMediaResource, credential: WebDAVCredential?) {
        self.init(reader: WebDAVMediaByteReader(resource: resource, credential: credential))
    }
    public init(reader: any NetworkMediaByteReader) {
        self.reader = reader
        let ext = (reader.fileName as NSString).pathExtension.lowercased()
        target = "/" + UUID().uuidString.lowercased() + "/video." + ext
    }

    public func start() async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                queue.async { [self] in
                    guard !self.started, !self.stopped else { continuation.resume(throwing: CancellationError()); return }
                    self.started = true; self.startup = continuation
                    do {
                        let parameters = NWParameters.tcp
                        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                        let listener = try NWListener(using: parameters)
                        self.listener = listener
                        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) ?? connection.cancel() }
                        listener.stateUpdateHandler = { [weak self] state in
                            guard let self else { return }
                            switch state {
                            case .ready:
                                guard let port = listener.port, let continuation = self.startup else { return }
                                self.localPort = port.rawValue; self.startup = nil
                                var url = URLComponents(); url.scheme = "http"; url.host = "127.0.0.1"
                                url.port = Int(port.rawValue); url.path = self.target
                                continuation.resume(returning: url.url!)
                            case .failed(let error): self.finish(error)
                            default: break
                            }
                        }
                        listener.start(queue: self.queue)
                        self.queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                            if self?.startup != nil { self?.finish(URLError(.timedOut)) }
                        }
                    } catch { self.finish(error) }
                }
            }
        }, onCancel: { self.stop() })
    }

    public func stop() { queue.async { self.finish(CancellationError()) } }
    private func finish(_ error: Error) {
        guard !stopped else { return }
        stopped = true
        let pending = startup; startup = nil
        listener?.newConnectionHandler = nil; listener?.stateUpdateHandler = nil
        listener?.cancel(); listener = nil
        for id in Array(clients.keys) { close(id) }
        pending?.resume(throwing: error)
    }
    private func accept(_ connection: NWConnection) {
        guard !stopped else { connection.cancel(); return }
        guard clients.count < Self.maximumClients else {
            // Send a finite, retryable error without starting another reader.
            connection.start(queue: queue)
            let response = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nRetry-After: 1\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), isComplete: true,
                completion: .contentProcessed { _ in connection.cancel() })
            queue.asyncAfter(deadline: .now() + 1) { connection.cancel() }
            return
        }
        let id = UUID(); clients[id] = Client(connection: connection)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { connection.cancel(); return }
            switch state {
            case .ready:
                guard self.clients[id]?.task == nil else { return }
                self.clients[id]?.task = Task { await self.serve(connection, id: id) }
            case .failed, .cancelled: self.close(id)
            default: break
            }
        }
        touch(id); connection.start(queue: queue)
    }
    private func close(_ id: UUID) {
        guard let client = clients.removeValue(forKey: id) else { return }
        client.idle?.cancel(); client.task?.cancel()
        client.connection.stateUpdateHandler = nil; client.connection.cancel()
    }
    private func touch(_ id: UUID) {
        guard clients[id] != nil else { return }
        clients[id]?.idle?.cancel()
        let timeout = DispatchWorkItem { [weak self] in self?.close(id) }
        clients[id]?.idle = timeout; queue.asyncAfter(deadline: .now() + 30, execute: timeout)
    }
    private func receive(_ connection: NWConnection, id: UUID) async throws -> Data {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.touch(id)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, complete, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let data, !data.isEmpty { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: complete ? URLError(.networkConnectionLost) : URLError(.badServerResponse)) }
                }
            }
        }
    }
    private func send(_ data: Data, _ connection: NWConnection, id: UUID) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.touch(id)
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                })
            }
        }
    }
    private func finishSending(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }
    private func serve(_ connection: NWConnection, id: UUID) async {
        defer { queue.async { self.close(id) } }
        var sentHeaders = false
        do {
            var header = Data()
            while header.range(of: Data("\r\n\r\n".utf8)) == nil {
                let data = try await receive(connection, id: id)
                guard header.count + data.count <= 16384 else { throw LocalHTTPError(status: 431) }
                header.append(data)
            }
            let port = await withCheckedContinuation { continuation in queue.async { continuation.resume(returning: self.localPort) } }
            guard let port else { throw CancellationError() }
            let request = try MediaLocalHTTPRequest(header, target: target, port: port, total: reader.byteCount)
            let length = request.end - request.start + 1
            var fields = "HTTP/1.1 \(request.partial ? "206 Partial Content" : "200 OK")\r\nContent-Length: \(length)\r\nAccept-Ranges: bytes\r\nContent-Type: application/octet-stream\r\nConnection: close\r\n"
            if request.partial { fields += "Content-Range: bytes \(request.start)-\(request.end)/\(reader.byteCount)\r\n" }
            fields += "\r\n"
            if request.head {
                try await send(Data(fields.utf8), connection, id: id); try await finishSending(connection); return
            }
            // Validate the first window before sending a success status. Later
            // failures close the body, never turn a partial window into EOF.
            try await reader.stream(offset: request.start, count: length) { body in
                if !sentHeaders { try await send(Data(fields.utf8), connection, id: id); sentHeaders = true }
                try await send(body, connection, id: id)
            }
            try await finishSending(connection)
        } catch is CancellationError { }
        catch {
            if !sentHeaders {
                let status = (error as? LocalHTTPError)?.status ?? 502
                let unsatisfied = status == 416 ? "Content-Range: bytes */\(reader.byteCount)\r\n" : ""
                let fields = "HTTP/1.1 \(status) Error\r\n\(unsatisfied)Content-Length: 0\r\nConnection: close\r\n\r\n"
                try? await send(Data(fields.utf8), connection, id: id)
                try? await finishSending(connection)
            }
        }
    }
    deinit {
        listener?.newConnectionHandler = nil; listener?.stateUpdateHandler = nil
        listener?.cancel()
        for client in clients.values { client.idle?.cancel(); client.task?.cancel(); client.connection.cancel() }
    }
}

private struct LocalHTTPError: Error { let status: Int }
struct MediaLocalHTTPRequest {
    let head: Bool
    let partial: Bool
    let start: Int64
    let end: Int64
    init(_ data: Data, target: String, port: UInt16, total: Int64) throws {
        guard total > 0, let text = String(data: data, encoding: .ascii), text.hasSuffix("\r\n\r\n") else { throw LocalHTTPError(status: 400) }
        let lines = text.components(separatedBy: "\r\n"), first = lines[0].split(separator: " ", omittingEmptySubsequences: false)
        guard first.count == 3, ["HTTP/1.0", "HTTP/1.1"].contains(first[2]) else { throw LocalHTTPError(status: 400) }
        guard first[1] == target else { throw LocalHTTPError(status: 404) }
        guard ["GET", "HEAD"].contains(first[0]) else { throw LocalHTTPError(status: 405) }
        head = first[0] == "HEAD"
        var headers: [String: String] = [:]
        for line in lines.dropFirst().dropLast(2) {
            guard !line.isEmpty, !line.hasPrefix(" "), !line.hasPrefix("\t"), let split = line.firstIndex(of: ":") else { throw LocalHTTPError(status: 400) }
            let key = String(line[..<split]).lowercased(), value = String(line[line.index(after: split)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, key.utf8.allSatisfy({ (97...122).contains($0) || $0 == 45 }), headers[key] == nil else { throw LocalHTTPError(status: 400) }
            headers[key] = value
        }
        guard headers["host"] == "127.0.0.1:\(port)", headers["transfer-encoding"] == nil,
              headers["content-length"].map({ $0 == "0" }) ?? true else { throw LocalHTTPError(status: 400) }
        guard let range = headers["range"] else { partial = false; start = 0; end = total - 1; return }
        partial = true
        guard range.hasPrefix("bytes="), !range.contains(",") else { throw LocalHTTPError(status: 416) }
        let numbers = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        func number(_ value: Substring) -> Int64? { !value.isEmpty && value.utf8.allSatisfy({ (48...57).contains($0) }) ? Int64(value) : nil }
        guard numbers.count == 2 else { throw LocalHTTPError(status: 416) }
        if numbers[0].isEmpty {
            guard let suffix = number(numbers[1]), suffix > 0 else { throw LocalHTTPError(status: 416) }
            start = total - min(total, suffix); end = total - 1
        } else {
            guard let lower = number(numbers[0]), lower < total else { throw LocalHTTPError(status: 416) }
            let upper: Int64
            if numbers[1].isEmpty { upper = total - 1 }
            else { guard let value = number(numbers[1]), value >= lower else { throw LocalHTTPError(status: 416) }; upper = min(value, total - 1) }
            start = lower; end = upper
        }
    }
}
#endif
