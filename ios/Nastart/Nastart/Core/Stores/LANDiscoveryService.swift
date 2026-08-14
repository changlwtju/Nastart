import Foundation
import Combine
import Darwin

final class LANDiscoveryService: NSObject, ObservableObject {
    @Published private(set) var devices: [DiscoveredNASDevice] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorKey: String?

    private let serviceTypes = ["_https._tcp.", "_http._tcp.", "_smb._tcp."]
    private var browsers: [NetServiceBrowser] = []
    private var resolvingServices: [ObjectIdentifier: NetService] = [:]
    private var probedURLs = Set<String>()
    private var searchGeneration = UUID()
    private var subnetScanTask: Task<Void, Never>?
    private var hadBrowserFailure = false
    private let discoverySessionDelegate = DSMCertificateTrustDelegate()
    private lazy var discoverySession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.2
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(
            configuration: configuration,
            delegate: discoverySessionDelegate,
            delegateQueue: nil
        )
    }()

    /// Reuse the verified Bonjour/subnet discovery for automatic credential
    /// restoration. Credentials are only sent after discovery identifies a
    /// DSM-compatible private endpoint.
    @MainActor
    static func discoverDSMEndpoints(timeout: TimeInterval = 12) async -> [URL] {
        let service = LANDiscoveryService()
        service.start()
        let nanoseconds = UInt64(max(timeout, 0.5) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        let endpoints = service.devices.compactMap { URL(string: $0.host) }
        service.stop()
        return endpoints
    }

    func start() {
        stop()
        devices = []
        errorKey = nil
        probedURLs.removeAll()
        isSearching = true
        hadBrowserFailure = false
        searchGeneration = UUID()
        let generation = searchGeneration
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.started"
        )

        for type in serviceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browsers.append(browser)
            browser.searchForServices(ofType: type, inDomain: "local.")
        }

        subnetScanTask = Task { [weak self] in
            await self?.scanLocalSubnets(generation: generation)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.searchGeneration == generation else { return }
            self.finish()
        }
    }

    func stop() {
        browsers.forEach { $0.stop() }
        resolvingServices.values.forEach { $0.stop() }
        subnetScanTask?.cancel()
        subnetScanTask = nil
        browsers.removeAll()
        resolvingServices.removeAll()
        isSearching = false
        searchGeneration = UUID()
    }

    private func finish() {
        guard isSearching else { return }
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        subnetScanTask?.cancel()
        subnetScanTask = nil
        isSearching = false
        if devices.isEmpty, hadBrowserFailure {
            errorKey = "connect.scan.permission"
        }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.completed",
            details: ["count": "\(devices.count)"]
        )
    }

    private func probe(service: NetService) {
        guard let hostName = service.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) else {
            return
        }
        let candidates: [URL]
        switch service.type {
        case "_https._tcp.":
            candidates = Self.serviceCandidates(scheme: "https", host: hostName, port: service.port)
        case "_http._tcp.":
            candidates = Self.serviceCandidates(scheme: "http", host: hostName, port: service.port)
        case "_smb._tcp.":
            candidates = Self.defaultDSMCandidates(host: hostName)
        default:
            return
        }
        let unprobedCandidates = candidates.filter { probedURLs.insert($0.absoluteString).inserted }
        guard !unprobedCandidates.isEmpty else { return }

        let displayName = service.name
        let generation = searchGeneration
        Task {
            guard let url = await preferredDSMURL(from: unprobedCandidates) else { return }
            await MainActor.run {
                guard self.searchGeneration == generation else { return }
                self.addDevice(name: displayName, url: url)
            }
        }
    }

    private func scanLocalSubnets(generation: UUID) async {
        let candidates = Self.localIPv4Prefixes().flatMap { prefix in
            (1...254).map { host in "\(prefix).\(host)" }
        }

        guard !candidates.isEmpty else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.subnet_started",
            details: [
                "hosts": "\(candidates.count)",
                "protocolCandidates": "\(candidates.count * 2)"
            ]
        )

        let batchSize = 32
        for startIndex in stride(from: 0, to: candidates.count, by: batchSize) {
            guard !Task.isCancelled else { return }
            let endIndex = min(startIndex + batchSize, candidates.count)
            let batch = Array(candidates[startIndex..<endIndex])
            let found = await withTaskGroup(of: URL?.self, returning: [URL].self) { group in
                for host in batch {
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        return await self.preferredDSMURL(
                            from: Self.defaultDSMCandidates(host: host)
                        )
                    }
                }
                var results: [URL] = []
                for await result in group {
                    if let result {
                        results.append(result)
                    }
                }
                return results
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.searchGeneration == generation else { return }
                for url in found {
                    let name = url.host.map { "DSM \($0)" } ?? "DSM"
                    self.addDevice(name: name, url: url)
                }
            }
        }
    }

    private func resolvedDSMBaseURL(at baseURL: URL) async -> URL? {
        guard
            let probeURL = DSMURLBuilder.url(baseURL: baseURL, appending: "/webapi/query.cgi"),
            var components = URLComponents(url: probeURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Info"),
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "method", value: "query"),
            URLQueryItem(name: "query", value: "SYNO.API.Auth,SYNO.Core.System")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                let envelope = try? JSONDecoder().decode(DSMAPIEnvelope.self, from: data),
                envelope.success,
                envelope.data?.objectValue?["SYNO.API.Auth"] != nil
            else {
                return nil
            }
            guard var resolvedComponents = URLComponents(
                url: response.url ?? baseURL,
                resolvingAgainstBaseURL: false
            ) else {
                return baseURL
            }
            let probeSuffix = "/webapi/query.cgi"
            if resolvedComponents.path.hasSuffix(probeSuffix) {
                resolvedComponents.path = String(resolvedComponents.path.dropLast(probeSuffix.count))
            } else {
                resolvedComponents.path = baseURL.path
            }
            resolvedComponents.query = nil
            resolvedComponents.fragment = nil
            return resolvedComponents.url ?? baseURL
        } catch {
            return nil
        }
    }

    private func preferredDSMURL(from candidates: [URL]) async -> URL? {
        await withTaskGroup(of: (Int, URL?).self, returning: URL?.self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    let resolvedURL = await self.resolvedDSMBaseURL(at: candidate)
                    return (index, resolvedURL)
                }
            }

            var matches: [(Int, URL)] = []
            for await (index, candidate) in group {
                if let candidate {
                    matches.append((index, candidate))
                }
            }
            return matches.min { $0.0 < $1.0 }?.1
        }
    }

    private static func defaultDSMCandidates(host: String) -> [URL] {
        serviceCandidates(scheme: "https", host: host, port: 5001)
            + serviceCandidates(scheme: "http", host: host, port: 5000)
    }

    private static func serviceCandidates(scheme: String, host: String, port: Int) -> [URL] {
        guard (1...65_535).contains(port) else { return [] }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        return components.url.map { [$0] } ?? []
    }

    private func addDevice(name: String, url: URL) {
        if let index = devices.firstIndex(where: {
            URL(string: $0.host)?.host?.caseInsensitiveCompare(url.host ?? "") == .orderedSame
        }) {
            guard
                let existingURL = URL(string: devices[index].host),
                protocolRank(url) < protocolRank(existingURL)
            else { return }
            devices[index] = DiscoveredNASDevice(
                id: devices[index].id,
                name: devices[index].name,
                host: url.absoluteString
            )
            recordDiscoveredDevice(url)
            return
        }
        devices.append(
            DiscoveredNASDevice(
                id: UUID(),
                name: name,
                host: url.absoluteString
            )
        )
        devices.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        recordDiscoveredDevice(url)
    }

    private func protocolRank(_ url: URL) -> Int {
        url.scheme?.lowercased() == "https" ? 0 : 1
    }

    private func recordDiscoveredDevice(_ url: URL) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.found",
            details: [
                "target": DiagnosticLogStore.redactedURL(url),
                "protocol": url.scheme?.uppercased() ?? "-"
            ]
        )
    }

    private static func localIPv4Prefixes() -> [String] {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let firstAddress = addresses else { return [] }
        defer { freeifaddrs(addresses) }

        var prefixes = Set<String>()
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard
                let socketAddress = current.pointee.ifa_addr,
                socketAddress.pointee.sa_family == UInt8(AF_INET),
                current.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                current.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else {
                continue
            }
            let interfaceName = String(cString: current.pointee.ifa_name)
            guard interfaceName.hasPrefix("en") else { continue }

            var address = UnsafeRawPointer(socketAddress)
                .assumingMemoryBound(to: sockaddr_in.self)
                .pointee
                .sin_addr
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                continue
            }

            let octets = String(cString: buffer).split(separator: ".").compactMap { Int($0) }
            guard octets.count == 4, isPrivateIPv4(octets) else { continue }
            prefixes.insert("\(octets[0]).\(octets[1]).\(octets[2])")
        }
        return prefixes.sorted()
    }

    private static func isPrivateIPv4(_ octets: [Int]) -> Bool {
        octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }
}
extension LANDiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        let identifier = ObjectIdentifier(service)
        resolvingServices[identifier] = service
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        guard browsers.contains(where: { $0 === browser }) else { return }
        browser.stop()
        browsers.removeAll { $0 === browser }
        hadBrowserFailure = true
        let values = errorDict.values.map(\.intValue)
        let code = values.first(where: { $0 < 0 }) ?? values.first ?? 0
        let domain = values.first(where: { $0 >= 0 }) ?? 0
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.failed",
            details: [
                "code": "\(code)",
                "domain": "\(domain)"
            ]
        )
    }
}

extension LANDiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        resolvingServices.removeValue(forKey: ObjectIdentifier(sender))
        probe(service: sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolvingServices.removeValue(forKey: ObjectIdentifier(sender))
    }
}
