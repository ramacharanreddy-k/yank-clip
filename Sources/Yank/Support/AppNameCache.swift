import AppKit

/// Resolves a bundle identifier to a human-readable app name, once.
///
/// A lookup hits Launch Services and the filesystem, and both call sites are
/// inside view bodies that re-evaluate constantly. Cached for the lifetime of
/// the app: installed apps do not move often enough to justify invalidation.
@MainActor
final class AppNameCache {

    static let shared = AppNameCache()

    /// Bundle ID → display name. The value is optional so a failed lookup is
    /// cached rather than retried forever.
    private var names: [String: String?] = [:]

    // Not annotated `@MainActor`: storing an explicitly isolated function type
    // crashed Swift 6.1.2 while generating its reabstraction thunk. The class is
    // main-actor isolated anyway, so every call already happens there.
    private let resolve: (String) -> String?

    /// The resolver is injectable so tests need not depend on which apps
    /// happen to be installed.
    init(resolve: @escaping (String) -> String? = AppNameCache.lookUpInstalledApp) {
        self.resolve = resolve
    }

    func displayName(forBundleID bundleID: String) -> String? {
        if let cached = names[bundleID] { return cached }
        let resolved = resolve(bundleID)
        names[bundleID] = resolved
        return resolved
    }

    // MARK: - Resolution

    nonisolated private static func lookUpInstalledApp(_ bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        // displayName honours localisation and Finder renames.
        let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
        return trimmingAppExtension(name)
    }

    /// Drops a trailing ".app"; a blanket replace would mangle a name that
    /// contains it mid-string.
    ///
    /// Pure, so it needs no isolation — and the default resolver that calls it
    /// is nonisolated.
    nonisolated static func trimmingAppExtension(_ name: String) -> String {
        name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
