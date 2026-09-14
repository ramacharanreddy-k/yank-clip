import Foundation
import Testing
@testable import Yank

/// Cost at the sizes the app actually allows: the remember cap tops out at
/// 1,000 clips, and a clip can be as large as whatever was copied.
///
/// The budgets are deliberately loose. They are regression alarms, not
/// benchmarks — the point is to notice an order-of-magnitude change, not to
/// fail on a busy machine.
@Suite("Performance")
@MainActor
struct PerformanceTests {

    private func makeStore() -> (ClipStore, URL) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "yank-perf-\(UUID().uuidString)")
            .appending(path: "history.json")
        return (ClipStore(rememberCount: 1000, storeURL: url, saveDelay: .seconds(3600)), url)
    }

    /// Times `work` and prints the result, so a run doubles as a report.
    private func elapsed(_ label: String, _ work: () -> Void) -> Double {
        let start = ContinuousClock.now
        work()
        let seconds = Double(start.duration(to: .now).components.attoseconds) / 1e18
        let padded = label.padding(toLength: 34, withPad: " ", startingAt: 0)
        print("  PERF  \(padded) \(String(format: "%7.1f", seconds * 1000)) ms")
        return seconds
    }

    @Test("recording into a full history stays responsive")
    func recordIntoFullHistory() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let body = String(repeating: "x", count: 2_000)
        for n in 1...1000 { store.record(text: "\(body)\(n)", sourceBundleID: nil) }

        // record() scans for an existing match, so the worst case is a miss
        // against a full history.
        let time = elapsed("record into 1000 clips") {
            store.record(text: "a clip that matches nothing", sourceBundleID: nil)
        }

        #expect(store.clips.count == 1000)
        #expect(time < 0.1, "one record took \(time)s against 1000 clips")
    }

    @Test("searching a full history stays responsive")
    func searchFullHistory() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let body = String(repeating: "lorem ipsum ", count: 200)
        for n in 1...1000 { store.record(text: "\(body)\(n)", sourceBundleID: nil) }

        // What every keystroke in the search field costs.
        let time = elapsed("search 1000 clips") {
            _ = store.visibleClips(matching: "ipsum", limit: 20)
        }

        #expect(time < 0.15, "one search took \(time)s against 1000 clips")
    }

    @Test("a very large clip does not stall capture")
    func largeClip() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        // Derived fields are computed once here, which is the whole reason they
        // are stored rather than computed on every render.
        let huge = String(repeating: "abcdefghij", count: 100_000)   // ~1 MB

        let time = elapsed("capture a 1MB clip") { store.record(text: huge, sourceBundleID: nil) }

        #expect(store.clips.count == 1)
        #expect(time < 0.5, "capturing a 1MB clip took \(time)s")
    }

    @Test("saving and loading a full history stays responsive")
    func persistFullHistory() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        for n in 1...1000 { store.record(text: "clip \(n)", sourceBundleID: "com.example.app") }

        let writeTime = elapsed("write 1000 clips") { store.saveNow() }

        let reloaded = ClipStore(rememberCount: 1000, storeURL: url, saveDelay: .seconds(3600))
        let readTime = elapsed("read 1000 clips") { reloaded.load() }

        #expect(reloaded.clips.count == 1000)
        #expect(writeTime < 1.0, "writing 1000 clips took \(writeTime)s")
        #expect(readTime < 1.0, "reading 1000 clips took \(readTime)s")
    }

    @Test("resolving what the menu shows is cheap enough for every keystroke")
    func menuStateResolution() {
        let clips = (1...1000).map { Clip(text: "clip \($0)") }
        let visible = Array(clips.prefix(20))

        let time = elapsed("resolve MenuState x100") {
            for _ in 0..<100 {
                _ = MenuState.resolve(clips: clips, visible: visible, query: "q",
                                      isRecording: true, loadError: nil)
            }
        }

        #expect(time < 0.05, "100 resolutions took \(time)s")
    }
}
