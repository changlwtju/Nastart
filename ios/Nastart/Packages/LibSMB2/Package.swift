// swift-tools-version: 5.9
import PackageDescription

// libsmb2 is LGPL-2.1, so it stays in its own dynamic framework: a user can replace
// it in a re-signed build without any of Nastart's own code changing.
let package = Package(
    name: "LibSMB2",
    platforms: [.iOS(.v16), .tvOS(.v16), .macOS(.v13)],
    products: [.library(name: "LibSMB2", type: .dynamic, targets: ["libsmb2"])],
    targets: [
        .target(
            name: "libsmb2",
            path: "Sources/libsmb2",
            sources: ["lib"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"), .headerSearchPath("include/apple"),
                .headerSearchPath("include/smb2"), .headerSearchPath("lib"),
                .define("_U_", to: "__attribute__((unused))"), .define("HAVE_CONFIG_H", to: "1"),
            ])
    ])
