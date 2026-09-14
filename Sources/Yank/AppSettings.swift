import Foundation
import Observation
import ServiceManagement

/// User preferences, backed by UserDefaults.
///
/// Each preference is a computed property over private storage, so validation,
/// persistence and change notification happen in one place.
///
/// Do not rewrite these as stored properties that clamp inside their own
/// `didSet`. `@Observable` turns stored properties into computed ones, so
/// assigning to the property from its observer re-enters the setter and
/// recurses until the stack overflows.
@MainActor
@Observable
final class AppSettings {

    /// The values Yank ships with. Registered as UserDefaults defaults *and*
    /// used by "Reset to Defaults", so the two cannot drift apart.
    enum Defaults {
        static let rememberCount = 200
        static let displayCount = 20
        static let isRecording = true

        static let menuWidth: Double = 420
        static let rowDensity: RowDensity = .comfortable
        static let showShortcutHints = true
        static let showSourceApp = false
    }

    /// Valid ranges, enforced by the setters rather than by the UI alone — a
    /// value can also arrive from a hand-edited defaults entry, and
    /// `UserDefaults.integer(forKey:)` returns 0 for a wrong-typed one.
    enum Limits {
        static let rememberCount: ClosedRange<Int> = 10...1000
        static let displayCount: ClosedRange<Int> = 5...50
        static let menuWidth: ClosedRange<Double> = 300...620
    }

    /// Stepper increments, kept beside the ranges they step through.
    enum Steps {
        static let rememberCount = 10
        static let displayCount = 5
        static let menuWidth: Double = 10
    }

    private enum Key {
        static let rememberCount = "rememberCount"
        static let displayCount = "displayCount"
        static let isRecording = "isRecording"
        static let menuWidth = "menuWidth"
        static let rowDensity = "rowDensity"
        static let showShortcutHints = "showShortcutHints"
        static let showSourceApp = "showSourceApp"
    }

    // MARK: - Storage
    //
    // Private so that every write goes through a validating setter. Still
    // observed, because the public computed properties read them inside a view
    // body and that registers the dependency.

    private var storedRememberCount: Int
    private var storedDisplayCount: Int
    private var storedIsRecording: Bool
    private var storedMenuWidth: Double
    private var storedRowDensity: RowDensity
    private var storedShowShortcutHints: Bool
    private var storedShowSourceApp: Bool

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - History

    /// Hard cap on stored clips; oldest evicted first.
    var rememberCount: Int {
        get { storedRememberCount }
        set {
            let clamped = newValue.clamped(to: Limits.rememberCount)
            guard clamped != storedRememberCount else { return }
            storedRememberCount = clamped
            defaults.set(clamped, forKey: Key.rememberCount)
            onChange?()
        }
    }

    /// How many clips the dropdown lists.
    var displayCount: Int {
        get { storedDisplayCount }
        set {
            let clamped = newValue.clamped(to: Limits.displayCount)
            guard clamped != storedDisplayCount else { return }
            storedDisplayCount = clamped
            defaults.set(clamped, forKey: Key.displayCount)
            onChange?()
        }
    }

    /// False pauses capture without discarding what is already stored.
    var isRecording: Bool {
        get { storedIsRecording }
        set {
            guard newValue != storedIsRecording else { return }
            storedIsRecording = newValue
            defaults.set(newValue, forKey: Key.isRecording)
            onChange?()
        }
    }

    // MARK: - Appearance

    /// Width of the dropdown, in points.
    var menuWidth: Double {
        get { storedMenuWidth }
        set {
            let clamped = newValue.clamped(to: Limits.menuWidth)
            guard clamped != storedMenuWidth else { return }
            storedMenuWidth = clamped
            defaults.set(clamped, forKey: Key.menuWidth)
            onChange?()
        }
    }

    var rowDensity: RowDensity {
        get { storedRowDensity }
        set {
            guard newValue != storedRowDensity else { return }
            storedRowDensity = newValue
            defaults.set(newValue.rawValue, forKey: Key.rowDensity)
            onChange?()
        }
    }

    var showShortcutHints: Bool {
        get { storedShowShortcutHints }
        set {
            guard newValue != storedShowShortcutHints else { return }
            storedShowShortcutHints = newValue
            defaults.set(newValue, forKey: Key.showShortcutHints)
            onChange?()
        }
    }

    var showSourceApp: Bool {
        get { storedShowSourceApp }
        set {
            guard newValue != storedShowSourceApp else { return }
            storedShowSourceApp = newValue
            defaults.set(newValue, forKey: Key.showSourceApp)
            onChange?()
        }
    }

    // MARK: - Change notification

    /// Called after any preference actually changes.
    ///
    /// `ClipStore` and `ClipboardMonitor` keep their own copies of a few of
    /// these values; pushing from here means no call site has to remember to
    /// tell them. Assigning a property the value it already holds does not
    /// fire it.
    @ObservationIgnored var onChange: (() -> Void)?

    // MARK: - Login item

    /// Mirrors the real SMAppService state rather than a preference of our own,
    /// so it stays honest if the user changes it in System Settings.
    private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    /// Set when registering or unregistering fails, so the UI can say why
    /// instead of appearing to do nothing. Ad-hoc signed builds outside
    /// /Applications are the usual cause.
    private(set) var launchAtLoginError: String?

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.rememberCount: Defaults.rememberCount,
            Key.displayCount: Defaults.displayCount,
            Key.isRecording: Defaults.isRecording,
            Key.menuWidth: Defaults.menuWidth,
            Key.rowDensity: Defaults.rowDensity.rawValue,
            Key.showShortcutHints: Defaults.showShortcutHints,
            Key.showSourceApp: Defaults.showSourceApp,
        ])
        // Registered defaults only apply when a key is absent, so a stored
        // value still has to be clamped on the way in.
        storedRememberCount = defaults.integer(forKey: Key.rememberCount)
            .clamped(to: Limits.rememberCount)
        storedDisplayCount = defaults.integer(forKey: Key.displayCount)
            .clamped(to: Limits.displayCount)
        storedIsRecording = defaults.bool(forKey: Key.isRecording)
        storedMenuWidth = defaults.double(forKey: Key.menuWidth)
            .clamped(to: Limits.menuWidth)
        storedRowDensity = RowDensity(rawValue: defaults.string(forKey: Key.rowDensity) ?? "")
            ?? Defaults.rowDensity
        storedShowShortcutHints = defaults.bool(forKey: Key.showShortcutHints)
        storedShowSourceApp = defaults.bool(forKey: Key.showSourceApp)
    }

    // MARK: - Appearance reset

    var appearanceIsDefault: Bool {
        menuWidth == Defaults.menuWidth
            && rowDensity == Defaults.rowDensity
            && showShortcutHints == Defaults.showShortcutHints
            && showSourceApp == Defaults.showSourceApp
    }

    func resetAppearance() {
        menuWidth = Defaults.menuWidth
        rowDensity = Defaults.rowDensity
        showShortcutHints = Defaults.showShortcutHints
        showSourceApp = Defaults.showSourceApp
    }

    // MARK: - Login item control

    /// Re-reads the real state; call when the settings window appears, since the
    /// user may have changed it in System Settings meanwhile.
    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        // Read the state back rather than assuming the call took effect.
        refreshLaunchAtLogin()
    }
}
