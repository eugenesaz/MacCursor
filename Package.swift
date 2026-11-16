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
            dependencies: ["MacCursorCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The menu bar app: overlay windows, event monitors, private SkyLight calls.
        .executableTarget(
            name: "MacCursorApp",
            dependencies: ["MacCursorCore", "MacCursorRender"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "MacCursorCoreTests", dependencies: ["MacCursorCore"]),
        .testTarget(name: "MacCursorRenderTests", dependencies: ["MacCursorRender"]),
    ],
    swiftLanguageModes: [.v6]
)
