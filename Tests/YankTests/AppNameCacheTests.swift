import Testing
@testable import Yank

/// Caching behaviour and name trimming. The resolver is injected, so nothing
/// here depends on which apps happen to be installed.
@Suite("AppNameCache")
@MainActor
struct AppNameCacheTests {

    /// Counts how many times a lookup actually reaches the resolver.
    private final class Counter {
        var calls: [String] = []
    }

    private func makeCache(returning result: @escaping (String) -> String?)
        -> (AppNameCache, Counter) {
        let counter = Counter()
        let cache = AppNameCache { bundleID in
            counter.calls.append(bundleID)
            return result(bundleID)
        }
        return (cache, counter)
    }

    @Test("a resolved name is returned and cached")
    func cachesHits() {
        let (cache, counter) = makeCache { _ in "Safari" }

        #expect(cache.displayName(forBundleID: "com.apple.Safari") == "Safari")
        #expect(cache.displayName(forBundleID: "com.apple.Safari") == "Safari")

        #expect(counter.calls == ["com.apple.Safari"])
    }

    @Test("a failed lookup is cached too, not retried forever")
    func cachesMisses() {
        let (cache, counter) = makeCache { _ in nil }

        #expect(cache.displayName(forBundleID: "com.example.gone") == nil)
        #expect(cache.displayName(forBundleID: "com.example.gone") == nil)
        #expect(cache.displayName(forBundleID: "com.example.gone") == nil)

        #expect(counter.calls.count == 1)
    }

    @Test("different identifiers are resolved independently")
    func separateEntries() {
        let (cache, counter) = makeCache { $0 == "a" ? "Alpha" : "Beta" }

        #expect(cache.displayName(forBundleID: "a") == "Alpha")
        #expect(cache.displayName(forBundleID: "b") == "Beta")
        #expect(cache.displayName(forBundleID: "a") == "Alpha")

        #expect(counter.calls == ["a", "b"])
    }

    @Test("only a trailing .app is trimmed")
    func trimsExtension() {
        #expect(AppNameCache.trimmingAppExtension("Safari.app") == "Safari")
        #expect(AppNameCache.trimmingAppExtension("Safari") == "Safari")
        // A blanket replace would mangle these.
        #expect(AppNameCache.trimmingAppExtension("My.app Thing") == "My.app Thing")
        #expect(AppNameCache.trimmingAppExtension("X.apple.app") == "X.apple")
    }
}
