// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hum",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hum",
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
