// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hum",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Carbon RegisterEventHotKey under the hood, so a global shortcut needs
        // no Accessibility permission at all.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Hum",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/Hum",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                // Embed Info.plist directly into the __TEXT segment so the
                // `swift run` binary is treated as an LSUIElement agent app.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Hum/Resources/Info.plist"
                ])
            ]
        )
    ]
)
