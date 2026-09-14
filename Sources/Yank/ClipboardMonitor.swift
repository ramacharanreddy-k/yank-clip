import AppKit
import Foundation

/// Watches a pasteboard and reports new copies.
///
/// Takes whichever pasteboard it is given, defaulting to
/// `NSPasteboard.general`. Free of SwiftUI imports by convention, so it stays
/// testable without a UI.
@MainActor
final class ClipboardMonitor {

    struct Capture {
        let text: String

        /// Bundle ID of the frontmost app, read when the change is noticed
        /// rather than when the copy happened — up to one poll interval later,
        /// so a best guess rather than a guarantee.
        let sourceBundleID: String?
    }

    /// Password managers opt out of clipboard history by declaring these
    /// types. Honouring them is what keeps passwords out of the history.
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private var timer: Timer?
    private var lastChangeCount: Int

    /// The changeCount produced by Yank's *own* write, to be ignored once.
    private var suppressedChangeCount: Int?

    /// False pauses capture. Driven by the "Record clipboard history" setting.
    var isRecording = true

    /// Whether the poll timer is currently scheduled.
    var isRunning: Bool { timer != nil }

    var onCapture: ((Capture) -> Void)?

    init(pasteboard: NSPasteboard = .general, interval: TimeInterval = 0.3) {
        self.pasteboard = pasteboard
        self.interval = interval
        // Seed with the current count so whatever is already on the pasteboard
        // at launch is not re-captured as if it were brand new.
        self.lastChangeCount = pasteboard.changeCount
    }

    // No deinit: it is not guaranteed to run on the main actor, so it cannot
    // touch `timer`. Teardown goes through `stop()`.

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // The timer is attached to the main run loop below, so this always
            // runs on the main thread; assumeIsolated states that to the
            // compiler without a hop.
            MainActor.assumeIsolated { self?.poll() }
        }
        // .common mode matters: a timer in the default mode stops firing the
        // moment a menu opens, which is exactly when Yank must keep watching.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops polling.
    ///
    /// The app pauses capture with `isRecording` instead, which keeps
    /// `lastChangeCount` moving so resuming does not report what was copied
    /// while paused as new.
    func stop() {
        timer?.invalidate()
        timer = nil
    }


    /// Puts text on the pasteboard on Yank's behalf, without recording it.
    ///
    /// The write bumps changeCount, which the next poll would otherwise read as
    /// a new copy — so a clip would duplicate itself every time it was clicked.
    /// Write and suppress are one operation so they cannot be separated, and so
    /// the write lands on the pasteboard this monitor watches.
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        suppressedChangeCount = pasteboard.changeCount
    }

    // MARK: - Polling

    /// One poll cycle. Internal so tests can drive it directly instead of
    /// waiting on the timer.
    func poll() {
        // Compare changeCount, never content: content comparison is slower and
        // misses re-copies of identical text, which must reorder the list.
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // changeCount only increases, so a token that is not this change has
        // been overtaken and can be dropped.
        if let suppressed = suppressedChangeCount {
            suppressedChangeCount = nil
            if suppressed == current { return }
        }

        guard isRecording, let capture = readPasteboard() else { return }
        onCapture?(capture)
    }

    private func readPasteboard() -> Capture? {
        let types = pasteboard.types ?? []
        guard !types.contains(Self.concealed), !types.contains(Self.transient) else { return nil }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        return Capture(text: text,
                       sourceBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }
}
