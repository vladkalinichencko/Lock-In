// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LockIn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LockIn", targets: ["LockIn"]),
        .executable(name: "LockInGuardian", targets: ["LockInGuardian"])
    ],
    targets: [
        .executableTarget(
            name: "LockIn",
            path: "Sources/LockIn"
        ),
        .executableTarget(
            name: "LockInGuardian",
            path: "Sources/LockInGuardian"
        ),
        .testTarget(
            name: "LockInTests",
            dependencies: ["LockIn"],
            path: "Tests/LockInTests"
        )
    ]
)
