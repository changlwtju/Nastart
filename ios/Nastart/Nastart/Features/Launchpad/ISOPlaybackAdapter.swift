import Foundation
import Network
import UDFRead

struct ISOPlaybackPreparation {
    let playbackURL: URL
    let fileExtension: String
    let selectedPath: String
    let titleCount: Int
}

enum ISOPlaybackError: Error {
    case invalidImage
    case rangeUnsupported
    case noPlayableTitle
    case proxyUnavailable
    case invalidResponse
}

enum ISOPlaybackAdapter {
    static func prepare(
        sourceURL: URL,
        allowsSelfSignedCertificates: Bool
    ) async throws -> ISOPlaybackPreparation {
        let reader = ISOHTTPRangeReader(
            url: sourceURL,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        let selections: [ISOPlaybackSelection]
        do {
            selections = try await ISO9660Index.load(using: reader).selections
        } catch ISOPlaybackError.invalidImage {
            selections = try await UDFRemoteIndex(url: sourceURL,
                allowsSelfSignedCertificates: allowsSelfSignedCertificates).load()
        }
        try Task.checkCancellation()
        guard let selection = selections.first else {
            throw ISOPlaybackError.noPlayableTitle
        }
        let playbackURL = try await ISOPlaybackProxy.shared.register(
            sourceURL: sourceURL,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            segments: selection.segments,
            fileExtension: selection.fileExtension
        )
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.iso_prepared",
            details: [
                "selectedPath": selection.displayPath,
                "segmentCount": String(selection.segments.count),
                "titleCount": String(selections.count),
                "virtualBytes": String(selection.segments.reduce(Int64(0)) { $0 + $1.length }),
                "format": selection.fileExtension
            ]
        )
        return ISOPlaybackPreparation(
            playbackURL: playbackURL,
            fileExtension: selection.fileExtension,
            selectedPath: selection.displayPath,
            titleCount: selections.count
        )
    }
}

private final class ISOTrustDelegate: NSObject, URLSessionDelegate {
    let trustedHost: String?
    let allowsSelfSignedCertificates: Bool

    init(trustedHost: String?, allowsSelfSignedCertificates: Bool) {
        self.trustedHost = trustedHost
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod
                == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost ?? "") == .orderedSame,
              allowsSelfSignedCertificates,
              let credential = CertificatePinStore.shared.credential(
                for: challenge,
                expectedHost: trustedHost
              ) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

private final class ISOHTTPRangeReader {
    let url: URL
    private let session: URLSession
    private let delegate: ISOTrustDelegate

    init(url: URL, allowsSelfSignedCertificates: Bool) {
        self.url = url
        delegate = ISOTrustDelegate(
            trustedHost: url.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard offset >= 0, length > 0 else { return Data() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("bytes=\(offset)-\(offset + Int64(length) - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ISOPlaybackError.invalidResponse
        }
        guard response.statusCode == 206 else {
            throw response.statusCode == 200
                ? ISOPlaybackError.rangeUnsupported
                : ISOPlaybackError.invalidResponse
        }
        var data = Data()
        data.reserveCapacity(length)
        for try await byte in bytes {
            data.append(byte)
            if data.count == length { break }
        }
        guard data.count == length else { throw ISOPlaybackError.invalidResponse }
        return data
    }
}

private final class UDFRemoteIndex: @unchecked Sendable {
    let sourceURL: URL
    let session: URLSession
    let delegate: ISOTrustDelegate
    private let lock = NSLock()
    private var cancelled = false
    private var activeRequest: URLSessionDataTask?
    private var cache: [UInt32: Data] = [:]
    private var cachedBytes = 0
    private var readBytes = 0
    private var selections: [String: [ISOSegment]] = [:]
    private let deadline = Date().addingTimeInterval(30)

    init(url: URL, allowsSelfSignedCertificates: Bool) {
        sourceURL = url
        delegate = ISOTrustDelegate(trustedHost: url.host, allowsSelfSignedCertificates: allowsSelfSignedCertificates)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 8
        config.timeoutIntervalForRequest = 5
        config.waitsForConnectivity = false
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        activeRequest?.cancel()
        lock.unlock()
    }

    private func read(lba: UInt32, buffer: UnsafeMutableRawPointer, count: UInt32) -> Int32 {
        lock.lock()
        let stopped = cancelled
        lock.unlock()
        guard !stopped, Date() < deadline, count > 0, count <= 8192 else { return 0 }
        let length = Int(count) * 2048
        if let data = cache[lba], data.count == length {
            data.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: length)
            return Int32(count)
        }
        guard readBytes + length <= 128 * 1024 * 1024 else { return 0 }
        readBytes += length
        let offset = Int64(lba) * 2048
        var request = URLRequest(url: sourceURL)
        request.setValue("bytes=\(offset)-\(offset + Int64(length) - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let done = DispatchSemaphore(value: 0)
        let result = UDFReadResult()
        let task = session.dataTask(with: request) { data, response, _ in
            if let response = response as? HTTPURLResponse,
               response.statusCode == 206,
               response.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(offset)-") == true,
               let data, data.count == length { result.data = data }
            done.signal()
        }
        lock.lock()
        activeRequest = task
        if cancelled { task.cancel() } else { task.resume() }
        lock.unlock()
        guard done.wait(timeout: .now() + 9) == .success, let data = result.data else {
            task.cancel()
            return 0
        }
        if cache[lba] == nil, cachedBytes + data.count <= 32 * 1024 * 1024 {
            cache[lba] = data
            cachedBytes += data.count
        }
        data.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: length)
        return Int32(count)
    }

    func load() async throws -> [ISOPlaybackSelection] {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { self.session.invalidateAndCancel() }
                    let context = Unmanaged.passUnretained(self).toOpaque()
                    let count = nastart_udf_scan(context, { context, lba, buffer, count in
                        guard let context, let buffer else { return 0 }
                        return Unmanaged<UDFRemoteIndex>.fromOpaque(context).takeUnretainedValue()
                            .read(lba: lba, buffer: buffer, count: count)
                    }, { context, path, offset, length in
                        guard let context, let path else { return }
                        let owner = Unmanaged<UDFRemoteIndex>.fromOpaque(context).takeUnretainedValue()
                        owner.selections[String(cString: path), default: []].append(
                            ISOSegment(sourceOffset: offset, length: length))
                    })
                    guard count > 0 else {
                        continuation.resume(throwing: ISOPlaybackError.noPlayableTitle)
                        return
                    }
                    let selections = self.selections.map { path, segments in
                        ISOPlaybackSelection(segments: segments, fileExtension: "m2ts", displayPath: path)
                    }.sorted { lhs, rhs in
                        lhs.segments.reduce(Int64(0)) { $0 + $1.length }
                            > rhs.segments.reduce(Int64(0)) { $0 + $1.length }
                    }
                    continuation.resume(returning: selections)
                }
            }
        } onCancel: { self.cancel() }
    }
}

private final class UDFReadResult: @unchecked Sendable {
    var data: Data?
}

private struct ISOSegment {
    let sourceOffset: Int64
    let length: Int64
}

private struct ISOPlaybackSelection {
    let segments: [ISOSegment]
    let fileExtension: String
    let displayPath: String
}

private struct ISOFileEntry {
    let path: String
    let name: String
    let extent: UInt32
    let size: UInt32
    let isDirectory: Bool
}

private struct ISO9660Index {
    static let sectorSize = 2_048
    let files: [ISOFileEntry]
    let selections: [ISOPlaybackSelection]

    var preferredPlaybackSelection: ISOPlaybackSelection? { selections.first }
    var playableSelectionCount: Int { selections.count }

    static func load(using reader: ISOHTTPRangeReader) async throws -> ISO9660Index {
        let descriptor = try await reader.read(offset: Int64(16 * sectorSize), length: sectorSize)
        guard descriptor.count == sectorSize,
              descriptor[0] == 1,
              String(data: descriptor.subdata(in: 1..<6), encoding: .ascii) == "CD001" else {
            throw ISOPlaybackError.invalidImage
        }
        guard let root = directoryRecord(in: descriptor, at: 156, parentPath: "") else {
            throw ISOPlaybackError.invalidImage
        }
        var files: [ISOFileEntry] = []
        var visited = Set<UInt32>()
        try await enumerate(
            directory: root,
            reader: reader,
            depth: 0,
            visited: &visited,
            files: &files
        )
        let selections = makeSelections(from: files)
        return ISO9660Index(files: files, selections: selections)
    }

    private static func enumerate(
        directory: ISOFileEntry,
        reader: ISOHTTPRangeReader,
        depth: Int,
        visited: inout Set<UInt32>,
        files: inout [ISOFileEntry]
    ) async throws {
        guard depth <= 8,
              files.count < 5_000,
              visited.insert(directory.extent).inserted else { return }
        let byteCount = Int(directory.size)
        guard byteCount > 0, byteCount <= 64 * 1_024 * 1_024 else {
            throw ISOPlaybackError.invalidImage
        }
        let data = try await reader.read(
            offset: Int64(directory.extent) * Int64(sectorSize),
            length: byteCount
        )
        var offset = 0
        var childDirectories: [ISOFileEntry] = []
        while offset < data.count {
            let recordLength = Int(data[offset])
            if recordLength == 0 {
                offset = min(((offset / sectorSize) + 1) * sectorSize, data.count)
                continue
            }
            guard offset + recordLength <= data.count else { break }
            if let entry = directoryRecord(
                in: data,
                at: offset,
                parentPath: directory.path
            ), entry.name != ".", entry.name != ".." {
                if entry.isDirectory {
                    childDirectories.append(entry)
                } else {
                    files.append(entry)
                }
            }
            offset += recordLength
        }
        for child in childDirectories {
            try await enumerate(
                directory: child,
                reader: reader,
                depth: depth + 1,
                visited: &visited,
                files: &files
            )
        }
    }

    private static func directoryRecord(
        in data: Data,
        at offset: Int,
        parentPath: String
    ) -> ISOFileEntry? {
        guard offset >= 0, offset + 34 <= data.count else { return nil }
        let recordLength = Int(data[offset])
        guard recordLength >= 34, offset + recordLength <= data.count else { return nil }
        let nameLength = Int(data[offset + 32])
        guard nameLength > 0, offset + 33 + nameLength <= data.count else { return nil }
        let rawName = data.subdata(in: (offset + 33)..<(offset + 33 + nameLength))
        let name: String
        if nameLength == 1, rawName[0] == 0 {
            name = "."
        } else if nameLength == 1, rawName[0] == 1 {
            name = ".."
        } else {
            name = (String(data: rawName, encoding: .ascii) ?? "")
                .replacingOccurrences(of: ";1", with: "", options: [.caseInsensitive])
        }
        guard !name.isEmpty else { return nil }
        let path = parentPath.isEmpty ? "/\(name)" : "\(parentPath)/\(name)"
        return ISOFileEntry(
            path: path,
            name: name,
            extent: littleEndianUInt32(data, offset + 2),
            size: littleEndianUInt32(data, offset + 10),
            isDirectory: data[offset + 25] & 0x02 != 0
        )
    }

    private static func littleEndianUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func makeSelections(from files: [ISOFileEntry]) -> [ISOPlaybackSelection] {
        var results: [ISOPlaybackSelection] = []
        let dvdPattern = try? NSRegularExpression(pattern: #"^VTS_(\d{2})_(\d)\.VOB$"#)
        var dvdGroups: [String: [(part: Int, file: ISOFileEntry)]] = [:]
        for file in files where file.path.uppercased().contains("/VIDEO_TS/") {
            let name = file.name.uppercased()
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            guard let match = dvdPattern?.firstMatch(in: name, range: range),
                  match.numberOfRanges == 3,
                  let titleRange = Range(match.range(at: 1), in: name),
                  let partRange = Range(match.range(at: 2), in: name),
                  let part = Int(name[partRange]), part > 0 else { continue }
            dvdGroups[String(name[titleRange]), default: []].append((part, file))
        }
        let dvdSelections = dvdGroups.values.compactMap { group -> ISOPlaybackSelection? in
            let sorted = group.sorted { $0.part < $1.part }
            guard let first = sorted.first else { return nil }
            return ISOPlaybackSelection(
                segments: sorted.map {
                    ISOSegment(sourceOffset: Int64($0.file.extent) * Int64(sectorSize), length: Int64($0.file.size))
                },
                fileExtension: "vob",
                displayPath: first.file.path
            )
        }
        results.append(contentsOf: dvdSelections.sorted { totalBytes($0) > totalBytes($1) })

        let playableExtensions: Set<String> = [
            "mp4", "m4v", "mov", "mkv", "avi", "webm", "ts", "m2ts", "mts",
            "mpeg", "mpg", "vob", "flv", "wmv", "rmvb", "ogv", "mxf"
        ]
        let alreadySelected = Set(results.flatMap { $0.segments.map(\.sourceOffset) })
        let dataSelections = files.compactMap { file -> ISOPlaybackSelection? in
            let ext = (file.name as NSString).pathExtension.lowercased()
            let sourceOffset = Int64(file.extent) * Int64(sectorSize)
            guard playableExtensions.contains(ext), !alreadySelected.contains(sourceOffset) else { return nil }
            return ISOPlaybackSelection(
                segments: [ISOSegment(sourceOffset: sourceOffset, length: Int64(file.size))],
                fileExtension: ext,
                displayPath: file.path
            )
        }
        results.append(contentsOf: dataSelections.sorted { totalBytes($0) > totalBytes($1) })
        return results
    }

    private static func totalBytes(_ selection: ISOPlaybackSelection) -> Int64 {
        selection.segments.reduce(0) { $0 + $1.length }
    }
}

private struct ISOProxyResource {
    let reader: ISOHTTPRangeReader
    let segments: [ISOSegment]
    let fileExtension: String
    let totalLength: Int64
}

private final class ISOPlaybackProxy: @unchecked Sendable {
    static let shared = ISOPlaybackProxy()

    private let queue = DispatchQueue(label: "com.changliwen.nastart.iso-proxy")
    private var listener: NWListener?
    private var port: NWEndpoint.Port?
    private var resources: [String: ISOProxyResource] = [:]

    func register(
        sourceURL: URL,
        allowsSelfSignedCertificates: Bool,
        segments: [ISOSegment],
        fileExtension: String
    ) async throws -> URL {
        let activePort = try await ensureStarted()
        let token = UUID().uuidString.lowercased()
        let resource = ISOProxyResource(
            reader: ISOHTTPRangeReader(
                url: sourceURL,
                allowsSelfSignedCertificates: allowsSelfSignedCertificates
            ),
            segments: segments,
            fileExtension: fileExtension,
            totalLength: segments.reduce(0) { $0 + $1.length }
        )
        queue.sync { resources[token] = resource }
        guard let url = URL(string: "http://127.0.0.1:\(activePort.rawValue)/iso/\(token).\(fileExtension)") else {
            throw ISOPlaybackError.proxyUnavailable
        }
        return url
    }

    private func ensureStarted() async throws -> NWEndpoint.Port {
        if let port = queue.sync(execute: { self.port }) { return port }
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let port = self.port {
                    continuation.resume(returning: port)
                    return
                }
                do {
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(
                        host: NWEndpoint.Host("127.0.0.1"),
                        port: .any
                    )
                    let listener = try NWListener(using: parameters)
                    self.listener = listener
                    var didResume = false
                    listener.stateUpdateHandler = { state in
                        self.queue.async {
                            switch state {
                            case .ready:
                                guard !didResume, let port = listener.port else { return }
                                didResume = true
                                self.port = port
                                continuation.resume(returning: port)
                            case .failed:
                                guard !didResume else { return }
                                didResume = true
                                continuation.resume(throwing: ISOPlaybackError.proxyUnavailable)
                            default:
                                break
                            }
                        }
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        self?.handle(connection)
                    }
                    listener.start(queue: self.queue)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1_024) {
            [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var requestData = accumulated
            if let data { requestData.append(data) }
            if requestData.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.serve(requestData, on: connection)
            } else if error != nil || isComplete || requestData.count > 64 * 1_024 {
                connection.cancel()
            } else {
                self.receiveRequest(on: connection, accumulated: requestData)
            }
        }
    }

    private func serve(_ requestData: Data, on connection: NWConnection) {
        guard let requestText = String(data: requestData, encoding: .utf8),
              let firstLine = requestText.components(separatedBy: "\r\n").first else {
            connection.cancel()
            return
        }
        let requestParts = firstLine.split(separator: " ")
        guard requestParts.count >= 2 else { connection.cancel(); return }
        let method = requestParts[0].uppercased()
        let path = String(requestParts[1])
        guard method == "GET" || method == "HEAD",
              let tokenWithExtension = path.split(separator: "/").last,
              let token = tokenWithExtension.split(separator: ".").first.map(String.init),
              let resource = resources[token] else {
            sendError(404, on: connection)
            return
        }
        let requestedRange = byteRange(from: requestText, totalLength: resource.totalLength)
        let range = requestedRange ?? (0...(resource.totalLength - 1))
        guard range.lowerBound >= 0,
              range.upperBound < resource.totalLength,
              range.lowerBound <= range.upperBound else {
            sendError(416, on: connection)
            return
        }
        let bodyLength = range.upperBound - range.lowerBound + 1
        let status = requestedRange == nil ? "200 OK" : "206 Partial Content"
        var headers = "HTTP/1.1 \(status)\r\n"
        headers += "Content-Type: \(mimeType(for: resource.fileExtension))\r\n"
        headers += "Accept-Ranges: bytes\r\n"
        headers += "Content-Length: \(bodyLength)\r\n"
        if requestedRange != nil {
            headers += "Content-Range: bytes \(range.lowerBound)-\(range.upperBound)/\(resource.totalLength)\r\n"
        }
        headers += "Connection: close\r\n\r\n"
        connection.send(content: Data(headers.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, method == "GET" else {
                connection.cancel()
                return
            }
            Task {
                do {
                    try await self?.stream(range: range, resource: resource, to: connection)
                } catch {
                    connection.cancel()
                }
            }
        })
    }

    private func stream(
        range: ClosedRange<Int64>,
        resource: ISOProxyResource,
        to connection: NWConnection
    ) async throws {
        var cursor = range.lowerBound
        var virtualStart: Int64 = 0
        while cursor <= range.upperBound {
            guard let segment = resource.segments.first(where: {
                cursor >= virtualStartFor($0, in: resource.segments)
                    && cursor < virtualStartFor($0, in: resource.segments) + $0.length
            }) else { throw ISOPlaybackError.invalidImage }
            virtualStart = virtualStartFor(segment, in: resource.segments)
            let withinSegment = cursor - virtualStart
            let available = min(segment.length - withinSegment, range.upperBound - cursor + 1)
            let chunkLength = Int(min(available, 512 * 1_024))
            let data = try await resource.reader.read(
                offset: segment.sourceOffset + withinSegment,
                length: chunkLength
            )
            try await send(data, on: connection)
            cursor += Int64(data.count)
        }
        connection.cancel()
    }

    private func virtualStartFor(_ segment: ISOSegment, in segments: [ISOSegment]) -> Int64 {
        var offset: Int64 = 0
        for candidate in segments {
            if candidate.sourceOffset == segment.sourceOffset && candidate.length == segment.length {
                return offset
            }
            offset += candidate.length
        }
        return offset
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        }
    }

    private func byteRange(from request: String, totalLength: Int64) -> ClosedRange<Int64>? {
        guard let line = request.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("range:")
        }), let marker = line.range(of: "bytes=", options: [.caseInsensitive]) else {
            return nil
        }
        let value = line[marker.upperBound...].trimmingCharacters(in: .whitespaces)
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        if parts[0].isEmpty, let suffix = Int64(parts[1]), suffix > 0 {
            return max(totalLength - suffix, 0)...(totalLength - 1)
        }
        guard let start = Int64(parts[0]) else { return nil }
        let end = parts[1].isEmpty ? totalLength - 1 : (Int64(parts[1]) ?? totalLength - 1)
        return start...min(end, totalLength - 1)
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension {
        case "mp4", "m4v": return "video/mp4"
        case "mkv": return "video/x-matroska"
        case "ts", "m2ts", "mts": return "video/mp2t"
        case "vob", "mpg", "mpeg": return "video/mpeg"
        default: return "application/octet-stream"
        }
    }

    private func sendError(_ status: Int, on connection: NWConnection) {
        let reason = status == 404 ? "Not Found" : "Range Not Satisfiable"
        let response = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
