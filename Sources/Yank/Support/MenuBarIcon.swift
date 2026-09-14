import AppKit

/// The status item image, kept out of YankApp so the scene declaration stays
/// about scenes.
extension NSImage {
    /// The menu bar glyph, drawn by Tools/IconGen.swift and copied into the
    /// bundle by build.sh.
    ///
    /// `isTemplate` is load-bearing: it is what makes AppKit recolour the glyph
    /// for light and dark menu bars. Without it the icon is invisible against
    /// one of the two.
    ///
    /// Falls back to an SF Symbol when the bundled asset is missing, which is
    /// the case when the binary runs outside the .app.
    ///
    /// `@MainActor` because `NSImage` is not `Sendable`: a global holding one
    /// is not concurrency-safe without isolation. It is only ever read from the
    /// scene body, which is already on the main actor.
    @MainActor
    static let yankMenuBarIcon: NSImage = {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Yank")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()
}
