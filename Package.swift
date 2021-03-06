// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "PointAndShoot",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PointAndShoot",
            targets: ["PointAndShoot"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jaredsinclair/etcetera.git", .branch("master")),
        .package(url: "https://github.com/jaredsinclair/OrientationObserver", .branch("master")),
    ],
    targets: [
        .target(
            name: "PointAndShoot",
            dependencies: [
                "OrientationObserver",
                "Etcetera"]),
        .testTarget(
            name: "PointAndShootTests",
            dependencies: ["PointAndShoot"]),
    ]
)
