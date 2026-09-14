import Foundation
import Observation
import os

/// The clip history: ordering, the remember cap, and persistence.
///
/// Persisted as JSON at ~/Library/Application Support/Yank/history.json with an
/// atomic write, debounced so a burst of copies does not hammer the disk.
@MainActor
@Observable
final class ClipStore {

    private(set) var clips: [Clip] = []

    /// Set when saved history could not be read at launch — there is nothing
    /// to show.
    private(set) var loadError: String?

    /// Set when a write failed. The clips remain in memory and usable, so the
    /// UI warns rather than hiding them.
    private(set) var saveError: String?

    /// Hard cap on stored clips. Lowering it evicts immediately.
    ///
    /// Enforced to be at least 1. Deliberately not clamped to
    /// `AppSettings.Limits.rememberCount`: that range describes what the
    /// settings UI offers, which is not a storage concern.
    var rememberCount: Int {
        get { storedRememberCount }
        set {
            let valid = max(1, newValue)
            guard valid != storedRememberCount else { return }
            storedRememberCount = valid
            if trimToCap() { scheduleSave() }
        }
    }


    // MARK: - Storage

    private var storedRememberCount: Int

    private let storeURL: URL
    private let saveDelay: Duration
    private var saveTask: Task<Void, Never>?

    private static let log = Logger(subsystem: "dev.ramacharan.yank", category: "ClipStore")

    /// ~/Library/Application Support/Yank/history.json
    ///
    /// A `let`, not a computed `var`: the location never changes, and AboutView
    /// reads it on every render.
    static let defaultStoreURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Yank/history.json")
    }()

    init(rememberCount: Int = AppSettings.Defaults.rememberCount,
         storeURL: URL = ClipStore.defaultStoreURL,
         saveDelay: Duration = .seconds(2)) {
        self.storedRememberCount = max(1, rememberCount)
        self.storeURL = storeURL
        self.saveDelay = saveDelay
    }

    // MARK: - Mutation

    /// Records a new capture.
    ///
    /// Re-copying text that is already in history moves that clip to the top
    /// rather than adding a duplicate row. The promoted clip keeps its original
    /// `id` — so the row is updated in place rather than replaced — but takes
    /// the *new* timestamp and source app, because it now represents the most
    /// recent copy and its provenance should say where that copy came from.
    func record(text: String, sourceBundleID: String?) {
        if let existing = clips.firstIndex(where: { $0.text == text }) {
            let promoted = Clip(id: clips[existing].id,
                                text: text,
                                createdAt: Date(),
                                sourceBundleID: sourceBundleID)
            clips.remove(at: existing)
            clips.insert(promoted, at: 0)
        } else {
            clips.insert(Clip(text: text, sourceBundleID: sourceBundleID), at: 0)
        }
        _ = trimToCap()
        scheduleSave()
    }

    /// Matches on `id`, not on equality.
    ///
    /// A view can hold a stale copy — re-copying existing text replaces the
    /// stored clip with one carrying a fresh `createdAt` — and an `==` match
    /// against it would silently find nothing.
    func delete(_ clip: Clip) {
        delete(ids: [clip.id])
    }

    /// Removes several clips at once — one save, not one per clip.
    func delete(ids: Set<Clip.ID>) {
        guard !ids.isEmpty else { return }
        let before = clips.count
        clips.removeAll { ids.contains($0.id) }
        guard clips.count != before else { return }
        scheduleSave()
    }

    func clearAll() {
        guard !clips.isEmpty else { return }
        clips.removeAll()
        scheduleSave()
    }

    /// Returns true if anything was evicted. `rememberCount` is clamped on
    /// assignment, so the cap is known valid here.
    @discardableResult
    private func trimToCap() -> Bool {
        guard clips.count > storedRememberCount else { return false }
        clips.removeLast(clips.count - storedRememberCount)
        return true
    }

    // MARK: - Queries

    /// The clips the dropdown should show: newest first, filtered by the search
    /// text, capped at the display count.
    func visibleClips(matching query: String, limit: Int) -> [Clip] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty
            ? clips
            : clips.filter { $0.text.localizedCaseInsensitiveContains(trimmed) }
        return Array(matches.prefix(max(0, limit)))
    }

    // MARK: - Persistence

    /// Replaces the in-memory history with what is on disk.
    ///
    /// Cancels any pending write first — it refers to the clips this call
    /// discards, and would otherwise overwrite the file just read.
    func load() {
        saveTask?.cancel()
        saveTask = nil

        guard FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)) else {
            // No file is an empty history, and this method replaces rather than
            // merges — leaving stale clips in place would contradict that.
            clips = []
            loadError = nil
            return
        }
        do {
            let data = try Data(contentsOf: storeURL)

            // A zero-byte file — what an interrupted write leaves behind — is
            // an empty history, not a decode failure.
            guard !data.isEmpty else {
                clips = []
                loadError = nil
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            clips = try decoder.decode([Clip].self, from: data)
            _ = trimToCap()
            loadError = nil
        } catch {
            // A corrupt file costs the user their history, not the app.
            Self.log.error(
                "could not read history: \(error.localizedDescription, privacy: .public)")
            loadError = String(format: String(localized: "error.read",
                                              defaultValue: "Could not read saved history: %@"),
                               error.localizedDescription)
            clips = []
        }
    }

    /// Coalesces a burst of copies into one disk write.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Writes immediately. Called on quit so nothing in flight is lost.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            // Owner-only directory: an atomic write publishes by rename, so
            // the file briefly carries default permissions before the chmod
            // below lands, and a private directory closes that window.
            let directory = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(clips)
            try data.write(to: storeURL, options: [.atomic])

            // This file holds real clipboard contents. Owner-only, never
            // group- or world-readable.
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: storeURL.path(percentEncoded: false))
            // A successful write also means the file on disk is good again.
            saveError = nil
            loadError = nil
        } catch {
            Self.log.error(
                "could not write history: \(error.localizedDescription, privacy: .public)")
            saveError = String(format: String(localized: "error.write",
                                              defaultValue: "Could not save history: %@"),
                               error.localizedDescription)
        }
    }
}
