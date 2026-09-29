// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "GalaGo", platforms: [.macOS(.v13), .iOS(.v16)], products: [.library(name: "GalaCore", targets: ["GalaCore"])], targets: [.target(name: "GalaCore"), .testTarget(name: "GalaCoreTests", dependencies: ["GalaCore"])])
