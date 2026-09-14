import Foundation
import Testing
@testable import Yank

/// Preference defaults, validation, persistence and change notification.
@Suite("AppSettings")
@MainActor
struct AppSettingsTests {

    /// In-memory defaults: nothing is read, clobbered or persisted, so no
    /// teardown is needed.
    private func makeSettings() -> (AppSettings, UserDefaults) {
        let defaults = InMemoryDefaults()
        return (AppSettings(defaults: defaults), defaults)
    }

    @Test("ships with the documented defaults")
    func shipsWithDefaults() {
        let (settings, _) = makeSettings()

        #expect(settings.rememberCount == 200)
        #expect(settings.displayCount == 20)
        #expect(settings.isRecording == true)
        #expect(settings.menuWidth == 420)
        #expect(settings.rowDensity == .comfortable)
        #expect(settings.showShortcutHints == true)
        #expect(settings.showSourceApp == false)
    }

    @Test("a change is written through immediately, with no separate save step")
    func writesThrough() {
        let (settings, defaults) = makeSettings()

        settings.rememberCount = 50
        settings.rowDensity = .compact

        #expect(defaults.integer(forKey: "rememberCount") == 50)
        #expect(defaults.string(forKey: "rowDensity") == "compact")
    }

    @Test("a stored value survives a new instance over the same defaults")
    func reloadsStoredValues() {
        let (settings, defaults) = makeSettings()
        settings.displayCount = 7
        settings.showSourceApp = true

        let reloaded = AppSettings(defaults: defaults)

        #expect(reloaded.displayCount == 7)
        #expect(reloaded.showSourceApp == true)
    }

    @Test("every preference notifies onChange")
    func notifiesOnChange() {
        let (settings, _) = makeSettings()
        var notifications = 0
        settings.onChange = { notifications += 1 }

        settings.rememberCount = 11
        settings.displayCount = 6
        settings.isRecording = false
        settings.menuWidth = 500
        settings.rowDensity = .roomy
        settings.showShortcutHints = false
        settings.showSourceApp = true

        #expect(notifications == 7)
    }

    @Test("out-of-range values are clamped, not stored as given")
    func clampsOutOfRange() {
        let (settings, _) = makeSettings()

        // Guards the clamping in AppSettings' setters.
        settings.rememberCount = 0
        #expect(settings.rememberCount == AppSettings.Limits.rememberCount.lowerBound)

        settings.rememberCount = 99_999
        #expect(settings.rememberCount == AppSettings.Limits.rememberCount.upperBound)

        settings.displayCount = -4
        #expect(settings.displayCount == AppSettings.Limits.displayCount.lowerBound)

        settings.menuWidth = 5_000
        #expect(settings.menuWidth == AppSettings.Limits.menuWidth.upperBound)

        settings.menuWidth = 1
        #expect(settings.menuWidth == AppSettings.Limits.menuWidth.lowerBound)
    }

    @Test("an invalid stored value is clamped when it is read back at launch")
    func clampsCorruptStoredValue() {
        let defaults = InMemoryDefaults()
        // Registered defaults only apply when the key is absent.
        defaults.set(0, forKey: "rememberCount")
        defaults.set(9_999, forKey: "menuWidth")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.rememberCount == AppSettings.Limits.rememberCount.lowerBound)
        #expect(settings.menuWidth == AppSettings.Limits.menuWidth.upperBound)
    }

    @Test("setting a value it already holds does not fire onChange")
    func noNotificationWithoutAChange() {
        let (settings, _) = makeSettings()
        var notifications = 0
        settings.onChange = { notifications += 1 }

        settings.rememberCount = settings.rememberCount
        settings.isRecording = settings.isRecording
        settings.rowDensity = settings.rowDensity
        // Clamps to a bound it already holds, so not a change.
        settings.menuWidth = 10_000
        settings.menuWidth = AppSettings.Limits.menuWidth.upperBound

        #expect(notifications == 1)   // only the first menuWidth move counts
    }

    @Test("reset restores appearance without touching history settings")
    func resetAppearance() {
        let (settings, _) = makeSettings()
        settings.rememberCount = 33
        settings.menuWidth = 610
        settings.rowDensity = .compact
        settings.showSourceApp = true
        #expect(settings.appearanceIsDefault == false)

        settings.resetAppearance()

        #expect(settings.appearanceIsDefault)
        #expect(settings.menuWidth == 420)
        #expect(settings.rowDensity == .comfortable)
        #expect(settings.showSourceApp == false)
        #expect(settings.rememberCount == 33)   // untouched
    }
}
