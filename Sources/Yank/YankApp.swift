import SwiftUI
import AppKit

/// Yank's entry point.
///
/// Two scenes: the menu bar dropdown, and the Settings window. There is no
/// main window — LSUIElement in Info.plist keeps the app out of the Dock.
@main
struct YankApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model)
        } label: {
            Image(nsImage: .yankMenuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

/// Owns the app model and handles the two lifecycle moments SwiftUI's App
/// protocol does not expose: setting the activation policy at launch, and
/// flushing the debounced save at quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Created eagerly because the scene body reads it when SwiftUI builds the
    /// MenuBarExtra, which happens before `applicationDidFinishLaunching`.
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement in Info.plist is what actually keeps Yank out of the Dock
        // and Cmd-Tab; setting the policy here too means running the binary
        // directly behaves the same as the assembled bundle.
        //
        // Yank never leaves .accessory. Switching to .regular — the only way to
        // show a Dock icon — disturbs how MenuBarExtra anchors its panel.
        NSApp.setActivationPolicy(.accessory)

        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Saves are debounced by two seconds, so flush whatever is still
        // pending or a clip copied just before quitting is lost.
        model.flush()
    }
}
