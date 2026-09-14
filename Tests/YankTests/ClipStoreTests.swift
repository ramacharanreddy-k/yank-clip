import Foundation
import Testing
@testable import Yank

/// History ordering, the remember cap, deletion, search and persistence.
@Suite("ClipStore")
@MainActor
struct ClipStoreTests {

    /// A store writing to a throwaway file, with a save delay long enough that
    /// the debounce never fires on its own — saves are triggered explicitly.
    private func makeStore(rememberCount: Int = AppSettings.Defaults.rememberCount)
        -> (ClipStore, URL) {
        let url = Self.temporaryStoreURL()
        return (ClipStore(rememberCount: rememberCount,
                          storeURL: url,
                          saveDelay: .seconds(3600)), url)
    }

    private static func temporaryStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "yank-tests-\(UUID().uuidString)")
            .appending(path: "history.json")
    }

    /// Removes the throwaway directory a test created. Tests that touch disk
    /// call this so a run does not leave litter behind in /tmp.
    private func removeStoreDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Waits for the debounced write to land, polling rather than sleeping for
    /// a fixed interval.
    ///
    /// A fixed sleep is a race: the suite runs tests in parallel, so the
    /// scheduler may not get to the save task within any particular window.
    /// The deadline is generous because it only bounds a failure, never a pass.
    private func loadWhenWritten(from url: URL,
                                 expecting count: Int,
                                 timeout: Duration = .seconds(10)) async -> ClipStore {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let store = ClipStore(rememberCount: 1000, storeURL: url,
                                  saveDelay: .seconds(3600))
            store.load()
            if store.clips.count == count { return store }
            try? await Task.sleep(for: .milliseconds(20))
        }
        let store = ClipStore(rememberCount: 1000, storeURL: url, saveDelay: .seconds(3600))
        store.load()
        return store
    }

    // MARK: Ordering

    @Test("newest clip goes to the top")
    func recordInsertsAtTop() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "first", sourceBundleID: nil)
        store.record(text: "second", sourceBundleID: nil)

        #expect(store.clips.map(\.text) == ["second", "first"])
    }

    @Test("re-copying existing text promotes it instead of duplicating")
    func reCopyPromotes() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "a", sourceBundleID: nil)
        store.record(text: "b", sourceBundleID: nil)
        store.record(text: "a", sourceBundleID: nil)

        #expect(store.clips.map(\.text) == ["a", "b"])
        #expect(store.clips.count == 2)
    }

    @Test("promotion keeps the original id so the row is not replaced")
    func promotionKeepsIdentity() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "a", sourceBundleID: nil)
        let originalID = store.clips[0].id
        store.record(text: "b", sourceBundleID: nil)
        store.record(text: "a", sourceBundleID: nil)

        #expect(store.clips[0].id == originalID)
    }

    // MARK: Cap

    @Test("the remember cap evicts the oldest clips")
    func capEvictsOldest() {
        let (store, storeURL) = makeStore(rememberCount: 3)
        defer { removeStoreDirectory(storeURL) }
        for n in 1...5 { store.record(text: "clip \(n)", sourceBundleID: nil) }

        #expect(store.clips.map(\.text) == ["clip 5", "clip 4", "clip 3"])
    }

    @Test("lowering the cap evicts immediately")
    func loweringCapEvicts() {
        let (store, storeURL) = makeStore(rememberCount: 10)
        defer { removeStoreDirectory(storeURL) }
        for n in 1...6 { store.record(text: "clip \(n)", sourceBundleID: nil) }

        store.rememberCount = 2

        #expect(store.clips.count == 2)
        #expect(store.clips.map(\.text) == ["clip 6", "clip 5"])
    }

    // MARK: Deletion

    @Test("a stale copy of a clip still deletes — matched by id, not by value")
    func deleteMatchesOnIdentity() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "a", sourceBundleID: nil)
        // A value a view could be holding: re-copying replaces the stored clip
        // with one carrying a fresh createdAt, so == would not match.
        let stale = store.clips[0]
        store.record(text: "b", sourceBundleID: nil)
        store.record(text: "a", sourceBundleID: nil)
        #expect(store.clips[0] != stale)

        store.delete(stale)

        #expect(store.clips.map(\.text) == ["b"])
    }

    @Test("bulk delete removes exactly the given ids")
    func bulkDelete() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        for n in 1...4 { store.record(text: "clip \(n)", sourceBundleID: nil) }
        let doomed = Set([store.clips[0].id, store.clips[2].id])

        store.delete(ids: doomed)

        #expect(store.clips.map(\.text) == ["clip 3", "clip 1"])
    }

    @Test("clearAll empties the history")
    func clearAll() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "a", sourceBundleID: nil)
        store.clearAll()

        #expect(store.clips.isEmpty)
    }

    // MARK: Querying

    @Test("search is case-insensitive and substring-based")
    func searchFilters() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "Hello World", sourceBundleID: nil)
        store.record(text: "goodbye", sourceBundleID: nil)

        #expect(store.visibleClips(matching: "hello", limit: 10).map(\.text) == ["Hello World"])
        #expect(store.visibleClips(matching: "O W", limit: 10).map(\.text) == ["Hello World"])
        #expect(store.visibleClips(matching: "  ", limit: 10).count == 2)
        #expect(store.visibleClips(matching: "nothing", limit: 10).isEmpty)
    }

    @Test("the display limit caps how many are returned")
    func searchRespectsLimit() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        for n in 1...10 { store.record(text: "clip \(n)", sourceBundleID: nil) }

        #expect(store.visibleClips(matching: "", limit: 3).count == 3)
        #expect(store.visibleClips(matching: "", limit: 0).isEmpty)
    }

    // MARK: Persistence

    @Test("saves and loads back in the same order")
    func persistenceRoundTrip() throws {
        let (store, url) = makeStore()
        defer { removeStoreDirectory(url) }
        store.record(text: "first", sourceBundleID: "com.example.app")
        store.record(text: "second", sourceBundleID: nil)
        store.saveNow()

        let reloaded = ClipStore(storeURL: url, saveDelay: .seconds(3600))
        reloaded.load()

        #expect(reloaded.clips.map(\.text) == ["second", "first"])
        #expect(reloaded.clips[1].sourceBundleID == "com.example.app")
        #expect(reloaded.loadError == nil)
    }

    @Test("the history file is owner-readable only")
    func historyFileIsPrivate() throws {
        let (store, url) = makeStore()
        defer { removeStoreDirectory(url) }
        store.record(text: "secret", sourceBundleID: nil)
        store.saveNow()

        let attributes = try FileManager.default
            .attributesOfItem(atPath: url.path(percentEncoded: false))
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)

        #expect(permissions.int16Value == 0o600)
    }

    @Test("an empty file is empty history, not an error")
    func emptyFileIsNotAnError() throws {
        let (_, url) = makeStore()
        defer { removeStoreDirectory(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data().write(to: url)

        let store = ClipStore(storeURL: url, saveDelay: .seconds(3600))
        store.load()

        #expect(store.clips.isEmpty)
        #expect(store.loadError == nil)
    }

    @Test("a corrupt file loses history but reports why, without throwing")
    func corruptFileIsReported() throws {
        let (_, url) = makeStore()
        defer { removeStoreDirectory(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)

        let store = ClipStore(storeURL: url, saveDelay: .seconds(3600))
        store.load()

        #expect(store.clips.isEmpty)
        #expect(store.loadError != nil)
    }

    @Test("promotion takes the newest source app, not the original one")
    func promotionTakesNewestProvenance() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "shared", sourceBundleID: "com.apple.Safari")
        store.record(text: "shared", sourceBundleID: "com.apple.Terminal")

        #expect(store.clips.count == 1)
        #expect(store.clips[0].sourceBundleID == "com.apple.Terminal")
    }

    @Test("the history directory is owner-only, not just the file")
    func historyDirectoryIsPrivate() throws {
        let (store, url) = makeStore()
        defer { removeStoreDirectory(url) }
        store.record(text: "secret", sourceBundleID: nil)
        store.saveNow()

        let directory = url.deletingLastPathComponent().path(percentEncoded: false)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)

        #expect(permissions.int16Value == 0o700)
    }

    @Test("a save failure is reported without discarding the clips")
    func saveFailureKeepsClipsInMemory() {
        // A directory cannot be created beneath a regular file.
        let blocker = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "yank-blocker-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: blocker.path(percentEncoded: false),
                                       contents: Data())
        defer { try? FileManager.default.removeItem(at: blocker) }
        let store = ClipStore(storeURL: blocker.appending(path: "nested/history.json"),
                              saveDelay: .seconds(3600))
        store.record(text: "still here", sourceBundleID: nil)

        store.saveNow()

        #expect(store.saveError != nil)
        #expect(store.loadError == nil)
        #expect(store.clips.map(\.text) == ["still here"])   // not thrown away
    }

    // MARK: Debounce

    @Test("a recorded clip is written after the debounce elapses, unprompted")
    func debouncedSaveFires() async throws {
        let url = Self.temporaryStoreURL()
        defer { removeStoreDirectory(url) }
        let store = ClipStore(storeURL: url, saveDelay: .milliseconds(50))

        store.record(text: "written by the debounce", sourceBundleID: nil)
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) == false)

        let reloaded = await loadWhenWritten(from: url, expecting: 1)

        #expect(reloaded.clips.map(\.text) == ["written by the debounce"])
    }

    @Test("a burst of copies coalesces into a single write")
    func debounceCoalesces() async throws {
        let url = Self.temporaryStoreURL()
        defer { removeStoreDirectory(url) }
        let store = ClipStore(storeURL: url, saveDelay: .milliseconds(80))

        for n in 1...20 { store.record(text: "clip \(n)", sourceBundleID: nil) }

        let reloaded = await loadWhenWritten(from: url, expecting: 20)

        // The single write holds the final state, not an intermediate.
        #expect(reloaded.clips.count == 20)
        let newest = try #require(reloaded.clips.first)
        #expect(newest.text == "clip 20")
    }

    @Test("loading cancels a pending write so stale clips cannot overwrite the file")
    func loadCancelsPendingSave() async throws {
        let url = Self.temporaryStoreURL()
        defer { removeStoreDirectory(url) }
        // Seed a file with known contents.
        let seeded = ClipStore(storeURL: url, saveDelay: .seconds(3600))
        seeded.record(text: "on disk", sourceBundleID: nil)
        seeded.saveNow()

        let store = ClipStore(storeURL: url, saveDelay: .milliseconds(50))
        store.record(text: "never persisted", sourceBundleID: nil)  // arms a save
        store.load()                                                 // must disarm it

        // Long enough that a save which was *not* cancelled would have landed.
        try await Task.sleep(for: .milliseconds(500))

        let reloaded = ClipStore(storeURL: url, saveDelay: .seconds(3600))
        reloaded.load()
        #expect(reloaded.clips.map(\.text) == ["on disk"])
    }

    // MARK: Guards

    @Test("loading when no file exists leaves an empty, error-free store")
    func loadWithNoFile() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }

        store.load()

        #expect(store.clips.isEmpty)
        #expect(store.loadError == nil)
    }

    @Test("loading replaces the in-memory history rather than merging into it")
    func loadReplacesRatherThanMerges() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "only in memory", sourceBundleID: nil)

        // Nothing was ever written, so the file does not exist.
        store.load()

        #expect(store.clips.isEmpty)
        #expect(store.loadError == nil)
    }

    @Test("a later successful write retires an earlier load error")
    func successfulSaveClearsLoadError() throws {
        let (_, url) = makeStore()
        defer { removeStoreDirectory(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)
        let store = ClipStore(storeURL: url, saveDelay: .seconds(3600))
        store.load()
        #expect(store.loadError != nil)

        store.record(text: "fresh start", sourceBundleID: nil)
        store.saveNow()

        #expect(store.loadError == nil)
        #expect(store.saveError == nil)
    }

    @Test("deleting ids that are not present changes nothing")
    func deleteUnknownIdsIsANoOp() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "keep", sourceBundleID: nil)

        store.delete(ids: [UUID(), UUID()])

        #expect(store.clips.map(\.text) == ["keep"])
    }

    @Test("clearing an already-empty store is harmless")
    func clearAllOnEmptyStore() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }

        store.clearAll()

        #expect(store.clips.isEmpty)
    }

    @Test("the cap can never drop below one clip")
    func capNeverDropsBelowOne() {
        let (store, storeURL) = makeStore()
        defer { removeStoreDirectory(storeURL) }
        store.record(text: "a", sourceBundleID: nil)
        store.record(text: "b", sourceBundleID: nil)

        store.rememberCount = 0
        #expect(store.rememberCount == 1)
        #expect(store.clips.count == 1)

        store.rememberCount = -10
        #expect(store.rememberCount == 1)
    }

    @Test("loading a file larger than the cap trims it")
    func loadRespectsCap() throws {
        let (store, url) = makeStore()
        defer { removeStoreDirectory(url) }
        for n in 1...10 { store.record(text: "clip \(n)", sourceBundleID: nil) }
        store.saveNow()

        let reloaded = ClipStore(rememberCount: 4, storeURL: url, saveDelay: .seconds(3600))
        reloaded.load()

        #expect(reloaded.clips.count == 4)
        #expect(reloaded.clips[0].text == "clip 10")
    }
}
