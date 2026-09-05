// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DMPCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "DMPCore", targets: ["DMPCore"])], targets: [.target(name: "DMPCore"), .testTarget(name: "DMPCoreTests", dependencies: ["DMPCore"])])
