import Foundation

/// Strings and selection arithmetic shared by the History tab.
///
/// Pure, so the labels that have been wrong before — "3 of 2 selected" — are
/// covered by tests rather than by looking at the window.
enum ClipPresentation {

    /// "13 Sep 2026 at 22:31 · Safari · 3 lines · 412 characters"
    ///
    /// `appName` is passed in rather than looked up, so this stays independent
    /// of which apps are installed.
    static func subtitle(for clip: Clip, appName: String?) -> String {
        let when = clip.createdAt.formatted(date: .abbreviated, time: .shortened)
        guard let appName else { return "\(when) · \(clip.shapeDescription)" }
        return "\(when) · \(appName) · \(clip.shapeDescription)"
    }

    /// What the History tab's toolbar reports.
    static func countLabel(total: Int, filtered: Int, selected: Int) -> String {
        if selected > 0 {
            return String(format: String(localized: "count.selected",
                                         defaultValue: "%1$lld of %2$lld selected"),
                          selected, total)
        }
        if filtered != total {
            return String(format: String(localized: "count.shown",
                                         defaultValue: "%1$lld of %2$lld shown"),
                          filtered, total)
        }
        if total == 1 { return String(localized: "count.one", defaultValue: "1 clip") }
        return String(format: String(localized: "count.many", defaultValue: "%lld clips"), total)
    }

    /// Drops ids for clips that no longer exist.
    ///
    /// Clips vanish from under a selection: evicted by the remember cap,
    /// deleted from the dropdown, or cleared.
    static func liveSelection(_ selection: Set<Clip.ID>, in clips: [Clip]) -> Set<Clip.ID> {
        selection.intersection(clips.map(\.id))
    }
}
