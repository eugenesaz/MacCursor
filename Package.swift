// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCursor",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "MacCursor", targets: ["MacCursorApp"])
    ],
    targets: [
        // Pure logic: no AppKit, no Core Animation. Fully unit-tested.
        .target(name: "MacCursorCore"),
        // Pointer art and layers (Core Graphics + Core Animation, no windows).
        .target(
            name: "MacCursorRender",
            dependencies: ["MacCursorCore"]
        ),
        // The menu bar app: overlay windows, event monitors, private SkyLight calls.
        .executableTarget(
            name: "MacCursorApp",
            dependencies: ["MacCursorCore", "MacCursorRender", "Sparkle"],
            linkerSettings: [
                // Finds Sparkle.framework in Contents/Frameworks of the app bundle.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        // Automatic updates: Sparkle's official prebuilt framework, fetched and checksum-verified
        // by scripts/fetch-sparkle.sh. scripts/bundle.sh embeds it in the app.
        .binaryTarget(name: "Sparkle", path: "Vendor/Sparkle.xcframework"),
        .testTarget(name: "MacCursorCoreTests", dependencies: ["MacCursorCore"]),
        .testTarget(
            name: "MacCursorRenderTests", dependencies: ["MacCursorRender"],
            exclude: ["Snapshots"]),
    ],
    swiftLanguageModes: [.v6]
)
