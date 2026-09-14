import Foundation

/// Owns the settings, the store and the monitor, and wires them together.
///
/// Not `@Observable`: it holds no mutable state, only `let` references.
/// `AppSettings` and `ClipStore` are observable themselves, so views reading
/// `model.store.clips` or `model.settings.…` are updated by those directly.
@MainActor
final class AppModel {

    let settings: AppSettings
    let store: ClipStore

    /// Internal so tests can drive `poll()` by hand. The app goes through the
    /// methods below.
    let monitor: ClipboardMonitor

    /// Dependencies are injectable so tests can supply a private pasteboard
    /// and a throwaway store file.
    init(settings: AppSettings = AppSettings(),
         monitor: ClipboardMonitor = ClipboardMonitor(),
         store: ClipStore? = nil) {
        self.settings = settings
        self.monitor = monitor
        // applySettings() below is the single place that pushes rememberCount.
        self.store = store ?? ClipStore()

        monitor.onCapture = { [weak self] capture in
            self?.store.record(text: capture.text, sourceBundleID: capture.sourceBundleID)
        }
        settings.onChange = { [weak self] in
            self?.applySettings()
        }
        applySettings()
    }

    /// Pushes the settings that the monitor and store hold their own copies
    /// of. Driven by `AppSettings.onChange`.
    private func applySettings() {
        monitor.isRecording = settings.isRecording
        store.rememberCount = settings.rememberCount
    }

    /// Loads saved history and begins watching the pasteboard.
    func start() {
        store.load()
        monitor.start()
    }

    /// Puts a clip back on the pasteboard.
    ///
    /// The user presses ⌘V themselves — pasting on their behalf would need the
    /// Accessibility permission, which v1 deliberately does not ask for.
    func apply(_ clip: Clip) {
        // Via the monitor, so the write lands on the pasteboard it watches and
        // the resulting change is suppressed in the same step.
        monitor.write(clip.text)
    }

    /// Writes any debounced save immediately. Called on quit.
    func flush() {
        store.saveNow()
    }
}
