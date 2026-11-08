import XCTest
@testable import NetworkMedia

final class NASServiceCategoryTests: XCTestCase {
    func testSharedGroupsRecognizeContainerImageNamesAndPunctuation() {
        let cases: [(String, NASServiceCategory)] = [
            ("ghcr.io/gethomepage/homepage:latest", .favorites),
            ("linuxserver/radarr:latest", .media), ("Sonarr", .media),
            ("lidarr-main", .media), ("readarr", .media), ("bazarr", .media),
            ("jellyfin-server", .media), ("Emby", .media), ("PlexMediaServer", .media),
            ("Navidrome", .media), ("Subsonic", .media),
            ("linuxserver/prowlarr", .downloads), ("overseerr", .downloads),
            ("qBittorrent", .downloads), ("Transmission", .downloads),
            ("MetaCubeXD", .network), ("mihomo", .network), ("AdGuard", .network),
            ("nginx-proxy-manager", .network), ("code-server", .tools),
            ("Home Assistant", .tools), ("Portainer", .tools)
        ]
        for (name, expected) in cases {
            XCTAssertEqual(NASServiceCategory.matching(name: name), expected, name)
        }
    }
    func testUnknownNamesStayUnknownAndMetadataCanSupplyTheIdentity() {
        XCTAssertNil(NASServiceCategory.matching(name: "my-custom-worker"))
        XCTAssertEqual(NASServiceCategory.matching(name: "media-worker", detail: "linuxserver/sonarr"), .media)
        XCTAssertEqual(NASServiceCategory.matching(name: "panel", aliases: ["homepage.example.invalid"]), .favorites)
        XCTAssertEqual(NASServiceCategory.matching(name: "DSM"), .favorites)
    }
    func testCuratedDefaultsKeepCommonInterfacesAndHideInfrastructure() {
        XCTAssertTrue(NASServiceCategory.defaultVisibleContainer(name: "homepage", image: "ghcr.io/gethomepage/homepage", hasAddress: true))
        XCTAssertTrue(NASServiceCategory.defaultVisibleContainer(name: "qb", image: "linuxserver/qbittorrent", hasAddress: true))
        XCTAssertFalse(NASServiceCategory.defaultVisibleContainer(name: "qb", image: "linuxserver/qbittorrent", hasAddress: false))
        XCTAssertFalse(NASServiceCategory.defaultVisibleContainer(name: "homepage-helper", image: "tecnativa/docker-socket-proxy:latest", hasAddress: true))
        XCTAssertFalse(NASServiceCategory.defaultVisibleContainer(name: "db", image: "mariadb:11", hasAddress: true))
        XCTAssertFalse(NASServiceCategory.defaultVisibleContainer(name: "cache", image: "redis:latest", hasAddress: true))
    }

}
