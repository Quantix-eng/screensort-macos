// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScreenSort",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ScreenSort", targets: ["ScreenSort"])],
    targets: [.executableTarget(name: "ScreenSort")]
)
