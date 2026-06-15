// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ble_agent",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ble_agent",
            targets: ["ble_agent"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ble_agent",
            dependencies: ["CaitunBleAgent"],
            path: "Classes",
            publicHeadersPath: nil,
            cSettings: [
                .headerSearchPath("Classes")
            ],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio")
            ]
        ),
        .binaryTarget(
            name: "CaitunBleAgent",
            path: "Frameworks/CaitunBleAgent.xcframework"
        )
    ]
)

