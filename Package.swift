// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Panora",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ejbills/mediaremote-adapter.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "Panora",
            dependencies: [
                .product(name: "MediaRemoteAdapter", package: "mediaremote-adapter")
            ],
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PanoraTests",
            dependencies: ["Panora"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),

    ]
)
