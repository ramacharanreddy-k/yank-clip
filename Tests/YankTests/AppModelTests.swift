import AppKit
import Foundation
import Testing
@testable import Yank

/// The wiring between settings, store and monitor.
@Suite("AppModel")
@MainActor
struct AppModelTests {

    /// Removes the throwaway store directory. Defaults are in-memory.
    private func removeStoreDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func makeModel() -> (model: AppModel, pasteboard: NSPasteboard, storeURL: URL) {
        let settings = AppSettings(defaults: InMemoryDefaults())
        let pasteboard = NSPasteboard(name: .init("dev.ramacharan.yank.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "yank-tests-\(UUID().uuidString)")
            .appending(path: "history.json")
        let model = AppModel(settings: settings,
                             monitor: ClipboardMonitor(pasteboard: pasteboard),
                             store: ClipStore(storeURL: storeURL, saveDelay: .seconds(3600)))
        return (model, pasteboard, storeURL)
    }

    @Test("a settings change reaches the store without the UI notifying by hand")
    func settingsPropagateToStore() {
        let (model, _, storeURL) = makeModel()
        defer { removeStoreDirectory(storeURL) }

        model.settings.rememberCount = 42

        #expect(model.store.rememberCount == 42)
    }

    @Test("pausing recording reaches the monitor")
    func recordingPropagatesToMonitor() {
        let (model, pasteboard, storeURL) = makeModel()
        defer { removeStoreDirectory(storeURL) }

        model.settings.isRecording = false
        pasteboard.clearContents()
        pasteboard.setString("while paused", forType: .string)
        model.monitor.poll()

        #expect(model.store.clips.isEmpty)
    }

    @Test("applying a clip puts it on the pasteboard and suppresses the read-back")
    func applyWritesAndSuppresses() {
        let (model, pasteboard, storeURL) = makeModel()
        defer { removeStoreDirectory(storeURL) }
        let clip = Clip(text: "put me back")

        model.apply(clip)

        #expect(pasteboard.string(forType: .string) == "put me back")

        // The following poll must not record it as a fresh copy.
        model.monitor.poll()
        #expect(model.store.clips.isEmpty)
    }

    @Test("a captured copy lands in the store")
    func captureReachesStore() {
        let (model, pasteboard, storeURL) = makeModel()
        defer { removeStoreDirectory(storeURL) }

        pasteboard.clearContents()
        pasteboard.setString("captured", forType: .string)
        model.monitor.poll()

        #expect(model.store.clips.map(\.text) == ["captured"])
    }
}
