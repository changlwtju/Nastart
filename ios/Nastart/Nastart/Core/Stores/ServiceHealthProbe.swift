import Foundation

struct ServiceHealthSnapshot: Equatable, Sendable {
    let status: ServiceStatus
    let latencyMilliseconds: Int?
    let checkedAt: Date
}

struct ServiceHealthTarget: Sendable {
    let id: UUID
    let url: URL
    var allowsSelfSignedCertificates = false
}

enum ServiceHealthProbe {
    private struct Result: Sendable {
        let id: UUID
        let snapshot: ServiceHealthSnapshot
    }

    private static let maximumConcurrentProbes = 6
    private static let timeout: TimeInterval = 3.5

    static func check(_ targets: [ServiceHealthTarget],
                      onResult: (@MainActor @Sendable (UUID, ServiceHealthSnapshot) -> Void)? = nil) async -> [UUID: ServiceHealthSnapshot] {
        await check(targets, perform: { await probe($0).snapshot }, onResult: onResult)
    }

    static func check(_ targets: [ServiceHealthTarget],
                      perform: @escaping @Sendable (ServiceHealthTarget) async -> ServiceHealthSnapshot,
                      onResult: (@MainActor @Sendable (UUID, ServiceHealthSnapshot) -> Void)? = nil) async -> [UUID: ServiceHealthSnapshot] {
        guard !targets.isEmpty, !Task.isCancelled else { return [:] }

        return await withTaskGroup(of: Result.self, returning: [UUID: ServiceHealthSnapshot].self) { group in
            var pending = targets.makeIterator()
            var snapshots: [UUID: ServiceHealthSnapshot] = [:]

            for _ in 0..<min(Self.maximumConcurrentProbes, targets.count) {
                guard let target = pending.next() else { break }
                group.addTask { Result(id: target.id, snapshot: await perform(target)) }
            }

            while let result = await group.next() {
                if Task.isCancelled { return [:] }
                snapshots[result.id] = result.snapshot
                await onResult?(result.id, result.snapshot)
                if let target = pending.next() {
                    group.addTask { Result(id: target.id, snapshot: await perform(target)) }
                }
            }
            return snapshots
        }
    }

    private static func probe(_ target: ServiceHealthTarget) async -> Result {
        let startedAt = Date()
        var request = URLRequest(url: target.url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = Self.timeout
        request.setValue("Nastart-ServiceHealth/1", forHTTPHeaderField: "User-Agent")

        let status: ServiceStatus
        do {
            let response = try await DSMClient(
                baseURL: target.url,
                allowsSelfSignedCertificates: target.allowsSelfSignedCertificates
            ).endpointProbeResponse(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                status = (200..<400).contains(httpResponse.statusCode) ? .online : .warning
            } else {
                status = .warning
            }
        } catch let error as URLError where error.code == .serverCertificateUntrusted {
            // Do not classify a service with a self-signed certificate as
            // unreachable. The app's explicit trust flow may still be valid.
            status = .warning
        } catch {
            status = .offline
        }

        let latency = max(0, Int((Date().timeIntervalSince(startedAt) * 1_000).rounded()))
        return Result(
            id: target.id,
            snapshot: ServiceHealthSnapshot(
                status: status,
                latencyMilliseconds: latency,
                checkedAt: Date()
            )
        )
    }
}

extension LaunchpadService {
    func replacing(status: ServiceStatus) -> LaunchpadService {
        LaunchpadService(
            id: id,
            name: name,
            iconText: iconText,
            category: category,
            status: status,
            subtitle: subtitle,
            detail: detail,
            isMedia: isMedia,
            cpu: cpu,
            memoryText: memoryText,
            memory: memory,
            ports: ports,
            iconURL: iconURL,
            endpoint: endpoint,
            alternateEndpoint: alternateEndpoint,
            source: source,
            isLaunchpadVisible: isLaunchpadVisible
        )
    }
}
