// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "throttle",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "throttle", targets: ["throttle"])
    ],
    targets: [
        .target(
            name: "ThrottleCore",
            path: "Sources/ThrottleCore",
            resources: [
                .copy("Profiles")
            ]
        ),
        .executableTarget(
            name: "throttle",
            dependencies: ["ThrottleCore"],
            path: "Sources/throttle"
        ),
        .testTarget(
            name: "throttleTests",
            dependencies: ["ThrottleCore"],
            path: "Tests/throttleTests"
        )
    ]
)
