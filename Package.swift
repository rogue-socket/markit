// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mdgrill",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "mdgrill",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources"
        )
    ]
)
