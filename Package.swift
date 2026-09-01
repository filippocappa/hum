// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hush",
            path: "Sources/Hush",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                // Embed Info.plist directly into the __TEXT segment so the
                // `swift run` binary is treated as an LSUIElement agent app.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Hush/Resources/Info.plist"
                ])
            ]
        )
    ]
)
