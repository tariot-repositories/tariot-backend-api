// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "MangoMonitorDashboardApi",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.4"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
        .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MangoMonitorDashboardApi",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "MQTTNIO", package: "mqtt-nio"),            
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "MangoMonitorDashboardApiTests",
            dependencies: [
                .target(name: "MangoMonitorDashboardApi"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
] }
