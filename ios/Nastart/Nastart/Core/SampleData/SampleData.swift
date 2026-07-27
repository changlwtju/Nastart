import Foundation

enum SampleData {
    static let device = NASDevice(
        id: UUID(uuidString: "45B4F6E7-339D-4E86-A33C-92A93463D33A")!,
        name: "DS918+",
        subtitle: "DSM 7.2.1 · Agent",
        mode: .dsmWithAgent,
        cpu: 0.11,
        memory: 0.32,
        storageUsed: 0.78,
        storageFreeText: "2.9 TB",
        uptimeText: "6d 21h",
        certificateDaysRemaining: 19
    )

    static let services: [LaunchpadService] = [
        LaunchpadService(id: UUID(uuidString: "A1F38D26-9B9F-43B3-965F-001A21D22401")!, name: "DSM", iconText: "DSM", category: .favorites, status: .online, subtitle: "service.dsm.subtitle", detail: "service.dsm.detail", isMedia: false, cpu: nil, memoryText: nil),
        LaunchpadService(id: UUID(uuidString: "776E95C2-12D1-42CF-A01D-A7D1F995B02D")!, name: "Jellyfin", iconText: "JF", category: .favorites, status: .online, subtitle: "service.jellyfin.subtitle", detail: "service.jellyfin.detail", isMedia: true, cpu: 0.08, memoryText: "504 MB"),
        LaunchpadService(id: UUID(uuidString: "6E1E6495-1E90-4F87-A423-B20E2A73A442")!, name: "qBittorrent", iconText: "QB", category: .downloads, status: .online, subtitle: "service.qb.subtitle", detail: "service.qb.detail", isMedia: false, cpu: 0.03, memoryText: "138 MB"),
        LaunchpadService(id: UUID(uuidString: "82A56666-10DC-4F32-8542-0902168EC67E")!, name: "Container", iconText: "CT", category: .tools, status: .warning, subtitle: "service.container.subtitle", detail: "service.container.detail", isMedia: false, cpu: nil, memoryText: nil),
        LaunchpadService(id: UUID(uuidString: "81C464AE-1E60-408A-AF3B-16D87BC059AB")!, name: "Navidrome", iconText: "NV", category: .media, status: .offline, subtitle: "service.navidrome.subtitle", detail: "service.navidrome.detail", isMedia: true, cpu: nil, memoryText: nil),
        LaunchpadService(id: UUID(uuidString: "5C49781A-1433-4244-ACB5-38D8362DC93A")!, name: "Nginx Proxy", iconText: "NG", category: .network, status: .online, subtitle: "service.nginx.subtitle", detail: "service.nginx.detail", isMedia: false, cpu: nil, memoryText: nil)
    ]

    static let tasks: [TaskItem] = [
        TaskItem(id: UUID(uuidString: "57F08602-CF5F-4B25-87ED-FED9C7AA03A1")!, title: "task.cert.title", subtitle: "task.cert.subtitle", symbol: "lock.shield", isUrgent: true),
        TaskItem(id: UUID(uuidString: "8060ED75-066A-4839-A987-67C2E36E6A77")!, title: "task.domain.title", subtitle: "task.domain.subtitle", symbol: "globe", isUrgent: false),
        TaskItem(id: UUID(uuidString: "FE673BF4-61C7-4F7E-B90D-5ABF6E20920E")!, title: "task.agent.title", subtitle: "task.agent.subtitle", symbol: "shippingbox", isUrgent: false)
    ]
}
