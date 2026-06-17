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
            name: "ble-agent",
            targets: ["ble_agent"]
        ),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "ble_agent",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "CaitunBleAgent",
                "JLAudioUnitKit",
                "Opus"
            ],
            path: "Sources/ble_agent",
            resources: [
                .process("PrivacyInfo.xcprivacy")
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
        ),
        .binaryTarget(
            name: "JLAudioUnitKit",
            path: "Frameworks/JLAudioUnitKit.xcframework"
        ),
        .binaryTarget(
            name: "Opus",
            path: "Frameworks/Opus.xcframework"
        )
    ]
)
