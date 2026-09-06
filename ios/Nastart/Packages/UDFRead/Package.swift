// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "UDFRead", platforms: [.iOS(.v15), .macOS(.v12)],
 products: [.library(name: "UDFRead", type: .dynamic, targets: ["UDFRead"])],
 targets: [.target(name: "UDFRead", publicHeadersPath: "include", cSettings: [
 .define("HAVE_UNISTD_H"), .define("HAVE_FCNTL_H"), .define("HAVE_PREAD"), .define("UDF_PUBLIC", to: "__attribute__((visibility(\"hidden\")))")])])
