// swift-tools-version: 5.9
import PackageDescription

// GlassyBattery.ext is a folder of JavaScript; this package is only its tests, and the way
// to gllink-ext (`swift run gllink-ext …`). Both come from GL-Link's extension SDK.
let package = Package(
    name: "GlassyBatteryExtension",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/DecKirin/gl-link-extensions", branch: "main"),
    ],
    targets: [
        .testTarget(name: "GlassyBatteryTests", dependencies: [
            .product(name: "GLLinkExtensionKit", package: "gl-link-extensions"),
            .product(name: "GLLinkExtensionTesting", package: "gl-link-extensions"),
        ]),
    ]
)
