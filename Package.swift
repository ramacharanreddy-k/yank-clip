// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Yank is built with SwiftPM rather than an .xcodeproj because Xcode is not
// installed on the development machine — only the Command Line Tools. The
// .app bundle is assembled by build.sh. See CLAUDE.md.

// swift-testing's macro plugin ships inside the Command Line Tools, but in a
// `plugins/testing/` subdirectory that the compiler does not scan — only the
// top level of `plugins/` is searched. Without pointing at it explicitly every
// @Test fails with "plugin for module 'TestingMacros' not found".
//
// Located at manifest time so the flag is only added when the library is
// actually there; with Xcode installed the plugin is found normally and this
// resolves to no extra flags.
let testingMacroPlugin: [SwiftSetting] = {
    let candidates = [
        "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib",
        "/Applications/Xcode.app/Contents/Developer/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib",
    ]
    guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        return []
    }
    return [.unsafeFlags(["-load-plugin-library", path])]
}()

let package = Package(
    name: "Yank",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Yank",
            path: "Sources/Yank",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "YankTests",
            dependencies: ["Yank"],
            path: "Tests/YankTests",
            swiftSettings: [.swiftLanguageMode(.v6)] + testingMacroPlugin
        ),
    ]
)
