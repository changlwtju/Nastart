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

    static let containers: [DockerContainer] = [
        DockerContainer(id: UUID(uuidString: "39DA8F61-DB3B-45E4-BAB6-9EEAF1F02AD5")!, name: "jellyfin", image: "jellyfin/jellyfin:latest", status: .online, cpu: 0.08, memoryText: "504 MB", ports: ["8096 -> 8096", "8920 -> 8920"]),
        DockerContainer(id: UUID(uuidString: "72B93F41-D66F-4048-967A-3F7087D05122")!, name: "navidrome", image: "deluan/navidrome:latest", status: .offline, cpu: 0.0, memoryText: "0 MB", ports: ["4533 -> 4533"]),
        DockerContainer(id: UUID(uuidString: "07DF8AC3-4F74-4FB0-AF54-67572A5191B9")!, name: "qbittorrent", image: "linuxserver/qbittorrent", status: .online, cpu: 0.03, memoryText: "138 MB", ports: ["8080 -> 8080", "6881 -> 6881"])
    ]

    static let files: [FileItem] = [
        FileItem(
            id: UUID(uuidString: "B928C44F-C3C5-4C7B-855D-D5CFC9077F84")!,
            name: "Media",
            subtitle: "/volume1/Media",
            kind: .folder,
            sizeText: nil,
            children: [
                FileItem(id: UUID(uuidString: "F8B6C6E9-F0C9-45D8-8F78-1A6D4A754315")!, name: "Movies", subtitle: "111 items", kind: .folder, sizeText: nil, children: [
                    FileItem(id: UUID(uuidString: "148B71EC-9C60-449C-9196-4D3E9F4016DC")!, name: "Steel Forest.mkv", subtitle: "Video · 4K", kind: .video, sizeText: "18.4 GB", children: []),
                    FileItem(id: UUID(uuidString: "D2536454-2852-43FA-9C41-8D699B82F55C")!, name: "Weekend Trip.mp4", subtitle: "Video · H.264", kind: .video, sizeText: "2.8 GB", children: [])
                ]),
                FileItem(id: UUID(uuidString: "8393A286-9F61-4D6C-9E3C-8594B6D27DCE")!, name: "Music", subtitle: "2,318 tracks", kind: .folder, sizeText: nil, children: [
                    FileItem(id: UUID(uuidString: "B2D7205E-42F6-476E-B50D-2D680430762B")!, name: "Morning Loop.flac", subtitle: "Audio · Lossless", kind: .audio, sizeText: "28 MB", children: [])
                ])
            ]
        ),
        FileItem(id: UUID(uuidString: "23E47235-5E72-41C2-B30B-1B2D46E18BD2")!, name: "Backup", subtitle: "/volume1/Backup", kind: .folder, sizeText: nil, children: [
            FileItem(id: UUID(uuidString: "D6027043-4270-4FE2-8E31-BE9F9C8EE4B1")!, name: "server-notes.txt", subtitle: "Text", kind: .text, sizeText: "14 KB", children: [])
        ]),
        FileItem(id: UUID(uuidString: "06171D0C-B15E-4C0D-A436-6C04711DE29C")!, name: "Photos", subtitle: "/volume1/Photos", kind: .folder, sizeText: nil, children: [
            FileItem(id: UUID(uuidString: "8A453908-68C1-4E7F-8C68-44A65621EE60")!, name: "desk-setup.heic", subtitle: "Image", kind: .image, sizeText: "3.2 MB", children: [])
        ])
    ]

    static let tasks: [TaskItem] = [
        TaskItem(id: UUID(uuidString: "57F08602-CF5F-4B25-87ED-FED9C7AA03A1")!, title: "task.cert.title", subtitle: "task.cert.subtitle", symbol: "lock.shield", isUrgent: true),
        TaskItem(id: UUID(uuidString: "8060ED75-066A-4839-A987-67C2E36E6A77")!, title: "task.domain.title", subtitle: "task.domain.subtitle", symbol: "globe", isUrgent: false),
        TaskItem(id: UUID(uuidString: "FE673BF4-61C7-4F7E-B90D-5ABF6E20920E")!, title: "task.agent.title", subtitle: "task.agent.subtitle", symbol: "shippingbox", isUrgent: false)
    ]

    static let videoLibraryItems: [MediaItem] = [
        MediaItem(id: UUID(uuidString: "24D28D7F-A608-47D8-872D-50FE0321AB03")!, title: "Steel Forest", subtitle: "Movie · 4K HDR", meta: "2h 08m", path: "/volume1/Media/Movies/Steel Forest.mkv", kind: .video),
        MediaItem(id: UUID(uuidString: "5D8F12B4-010D-45D6-9286-7BE98F6CC111")!, title: "Weekend Trip", subtitle: "Movie · H.264", meta: "38m", path: "/volume1/Media/Movies/Weekend Trip.mp4", kind: .video),
        MediaItem(id: UUID(uuidString: "235C2B53-76F3-4E08-8AA0-54C06D502816")!, title: "Station Notes", subtitle: "Show · Season 1", meta: "8 episodes", path: "/volume1/Media/Shows/Station Notes", kind: .video)
    ]

    static let audioLibraryItems: [MediaItem] = [
        MediaItem(id: UUID(uuidString: "E35850A6-0908-45B8-9909-BB2C1A47C587")!, title: "Morning Loop", subtitle: "Album · Lossless", meta: "12 tracks", path: "/volume1/Media/Music/Morning Loop", kind: .audio),
        MediaItem(id: UUID(uuidString: "E94A049A-4208-47B5-B4BA-883294284388")!, title: "Late Compile", subtitle: "Playlist", meta: "36 tracks", path: "/volume1/Media/Music/Playlists/Late Compile", kind: .audio),
        MediaItem(id: UUID(uuidString: "328AD2CF-33DA-4254-96D9-B3227149344B")!, title: "Night Drive", subtitle: "Single · FLAC", meta: "4m", path: "/volume1/Media/Music/Night Drive.flac", kind: .audio)
    ]

    static let discoveredDevices: [DiscoveredNASDevice] = [
        DiscoveredNASDevice(id: UUID(uuidString: "BDF8F257-1DE2-4B96-9DA9-F467CA4B3084")!, name: "DS918+", host: "https://192.168.1.20:5001"),
        DiscoveredNASDevice(id: UUID(uuidString: "9B2588CE-556C-4C75-A711-08A3587FE0B6")!, name: "Nastart Lab", host: "https://192.168.1.31:5001")
    ]
}
