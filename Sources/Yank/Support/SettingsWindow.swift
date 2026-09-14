import AppKit

/// Locates the Settings window.
///
/// Yank is an accessory app (LSUIElement) and stays that way for its whole
/// lifetime — it never switches activation policy, so it never shows a Dock
/// icon. `.regular` activation disturbs how `MenuBarExtra` anchors its panel,
/// which is a far worse trade than the icon is worth.
@MainActor
enum SettingsWindow {

    /// SwiftUI's Settings scene names its window this, and uses the same string
    /// as the UserDefaults key for the window's saved frame.
    static let autosaveName = "com_apple_SwiftUI_Settings_window"

    /// Pure, so it can be tested without an NSApplication.
    static func find(in windows: [NSWindow]) -> NSWindow? {
        windows.first { $0.frameAutosaveName == autosaveName }
    }

    static var current: NSWindow? { find(in: NSApp.windows) }
}
