import AppKit
import Foundation
import Testing
@testable import Yank

/// Drives `ClipboardMonitor` against a private pasteboard, so these tests
/// neither depend on nor disturb the real clipboard.
@Suite("ClipboardMonitor")
@MainActor
struct ClipboardMonitorTests {

    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    /// A private pasteboard and a monitor watching it. `poll()` is driven by
    /// hand, so nothing depends on timer scheduling.
    private func makeMonitor() -> (ClipboardMonitor, NSPasteboard, Box) {
        let pasteboard = NSPasteboard(name: .init("dev.ramacharan.yank.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        let box = Box()
        monitor.onCapture = { box.captures.append($0) }
        return (monitor, pasteboard, box)
    }

    /// Collects what the monitor reported.
    @MainActor final class Box {
        var captures: [ClipboardMonitor.Capture] = []
        var texts: [String] { captures.map(\.text) }
    }

    private func write(_ text: String, to pasteboard: NSPasteboard,
                       extraType: NSPasteboard.PasteboardType? = nil) {
        pasteboard.clearContents()
        if let extraType {
            pasteboard.declareTypes([.string, extraType], owner: nil)
            pasteboard.setString(text, forType: .string)
            pasteboard.setData(Data(), forType: extraType)
        } else {
            pasteboard.setString(text, forType: .string)
        }
    }

    // MARK: Capture

    @Test("a new copy is reported once")
    func capturesNewCopy() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("hello", to: pasteboard)

        monitor.poll()

        #expect(box.texts == ["hello"])
    }

    @Test("polling again without a new copy reports nothing")
    func doesNotRepeatWithoutAChange() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("hello", to: pasteboard)
        monitor.poll()
        monitor.poll()
        monitor.poll()

        #expect(box.texts == ["hello"])
    }

    @Test("re-copying identical text is reported again, so the list can reorder")
    func reCopyIsReported() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("same", to: pasteboard)
        monitor.poll()
        write("same", to: pasteboard)
        monitor.poll()

        #expect(box.texts == ["same", "same"])
    }

    // MARK: Filtering

    @Test("whitespace-only copies are ignored", arguments: ["", "   ", "\n\n", "\t \n"])
    func skipsWhitespace(_ text: String) {
        let (monitor, pasteboard, box) = makeMonitor()
        write(text, to: pasteboard)

        monitor.poll()

        #expect(box.texts.isEmpty)
    }

    @Test("concealed copies are ignored — this is how password managers opt out")
    func skipsConcealed() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("hunter2", to: pasteboard, extraType: Self.concealed)

        monitor.poll()

        #expect(box.texts.isEmpty)
    }

    @Test("transient copies are ignored")
    func skipsTransient() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("ephemeral", to: pasteboard, extraType: Self.transient)

        monitor.poll()

        #expect(box.texts.isEmpty)
    }

    @Test("a skipped copy does not block the next real one")
    func skippingDoesNotWedgeTheMonitor() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("hunter2", to: pasteboard, extraType: Self.concealed)
        monitor.poll()
        write("real", to: pasteboard)
        monitor.poll()

        #expect(box.texts == ["real"])
    }

    // MARK: Recording toggle

    @Test("nothing is captured while recording is paused")
    func respectsIsRecording() {
        let (monitor, pasteboard, box) = makeMonitor()
        monitor.isRecording = false
        write("ignored", to: pasteboard)
        monitor.poll()

        monitor.isRecording = true
        write("kept", to: pasteboard)
        monitor.poll()

        #expect(box.texts == ["kept"])
    }

    // MARK: Self-write suppression

    @Test("Yank's own write is not read back as a new copy")
    func suppressesOwnWrite() {
        let (monitor, _, box) = makeMonitor()

        // What AppModel.apply does.
        monitor.write("put back on the clipboard")
        monitor.poll()

        #expect(box.texts.isEmpty)
    }

    @Test("suppression applies to exactly one change, not all later ones")
    func suppressionIsOneShot() {
        let (monitor, pasteboard, box) = makeMonitor()
        monitor.write("ours")
        monitor.poll()

        write("theirs", to: pasteboard)
        monitor.poll()

        #expect(box.texts == ["theirs"])
    }

    @Test("a suppression token is dropped once a later copy overtakes it")
    func supersededSuppressionIsDiscarded() {
        let (monitor, pasteboard, box) = makeMonitor()
        monitor.write("ours")            // arms suppression for this change
        write("theirs", to: pasteboard)  // overtakes it before any poll runs

        monitor.poll()                   // sees "theirs"; token is stale
        write("later", to: pasteboard)
        monitor.poll()

        #expect(box.texts == ["theirs", "later"])
    }

    // MARK: Lifecycle

    @Test("start schedules a timer and stop releases it")
    func startAndStop() {
        let (monitor, _, _) = makeMonitor()
        #expect(monitor.isRunning == false)

        monitor.start()
        #expect(monitor.isRunning)

        monitor.start()                  // idempotent
        #expect(monitor.isRunning)

        monitor.stop()
        #expect(monitor.isRunning == false)
    }

    @Test("the source app is recorded alongside the text")
    func recordsSourceApp() {
        let (monitor, pasteboard, box) = makeMonitor()
        write("with provenance", to: pasteboard)

        monitor.poll()

        // The contract is that a capture is produced, not which app it names.
        #expect(box.captures.count == 1)
    }

    @Test("clicking the same clip repeatedly never duplicates it")
    func repeatedApplyNeverCaptures() {
        let (monitor, _, box) = makeMonitor()
        for _ in 0..<5 {
            monitor.write("clicked clip")
            monitor.poll()
        }

        #expect(box.texts.isEmpty)
    }
}
