// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NetworkMedia", platforms: [.iOS(.v16), .tvOS(.v16), .macOS(.v13)],
    products: [.library(name: "NetworkMedia", targets: ["NetworkMedia"])],
    dependencies: [.package(path: "../LibSMB2")],
    targets: [.target(name: "NetworkMedia", dependencies: [.product(name: "LibSMB2", package: "LibSMB2")]),
        .testTarget(name: "NetworkMediaTests", dependencies: ["NetworkMedia"], resources: [.copy("Fixtures")])])
