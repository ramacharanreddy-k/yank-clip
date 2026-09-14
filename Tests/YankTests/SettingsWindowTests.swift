import AppKit
import Testing
@testable import Yank

/// Finding the Settings window among the app's windows, so focus can be
/// cleared on the right one.
@Suite("SettingsWindow")
@MainActor
struct SettingsWindowTests {

    private func window(autosaveName: String) -> NSWindow {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 100, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: true)
        window.setFrameAutosaveName(autosaveName)
        return window
    }

    @Test("finds the Settings window by autosave name")
    func findsSettingsWindow() {
        let settings = window(autosaveName: SettingsWindow.autosaveName)
        let other = window(autosaveName: "something.else")

        #expect(SettingsWindow.find(in: [other, settings]) === settings)
    }

    @Test("returns nil when no window matches")
    func noMatch() {
        #expect(SettingsWindow.find(in: [window(autosaveName: "a")]) == nil)
        #expect(SettingsWindow.find(in: []) == nil)
    }

    @Test("a window with no autosave name is not mistaken for Settings")
    func ignoresUnnamedWindows() {
        #expect(SettingsWindow.find(in: [window(autosaveName: "")]) == nil)
    }
}
