// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PinRoutes",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PinRoutes",
            path: "Sources/PinRoutes",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "pinroutes-helper",
            path: "Sources/PinRoutesHelper"
        )
    ]
)
