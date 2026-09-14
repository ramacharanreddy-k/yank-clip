import AppKit
import SwiftUI

/// Lets the menu bar panel accept keyboard input as soon as it opens.
///
/// `MenuBarExtra(.window)` presents its content in a non-activating `NSPanel`
/// whose `becomesKeyOnlyIfNeeded` is set, so the panel takes key status only
/// after the user clicks a control inside it. Until then the window is not key,
/// and no SwiftUI focus API can help: `@FocusState` and `.defaultFocus` both
/// require a key window. The search field therefore ignores typing until it has
/// been clicked once.
///
/// Clearing the flag and making the panel key restores type-to-filter. This has
/// to reach through to AppKit because SwiftUI exposes no control over the panel
/// it creates.
struct PanelKeyFocus: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        // The view has no window yet during make; wait for it to be installed.
        DispatchQueue.main.async { makePanelKey(around: probe) }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // The panel is recreated each time the menu opens, so re-apply — but
        // this runs on every SwiftUI update, including every keystroke in the
        // search field, so do nothing once the panel is already configured.
        guard let panel = nsView.window as? NSPanel else { return }
        guard panel.becomesKeyOnlyIfNeeded || !panel.isKeyWindow else { return }
        makePanelKey(around: nsView)
    }

    private func makePanelKey(around view: NSView) {
        guard let panel = view.window as? NSPanel else { return }
        panel.becomesKeyOnlyIfNeeded = false
        guard !panel.isKeyWindow else { return }
        panel.makeKey()
    }
}
