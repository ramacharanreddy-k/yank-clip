import SwiftUI

/// The preferences window: one tab per area, in the standard macOS style.
///
/// Each tab sets its own frame (see `SettingsMetrics`) so the window resizes to
/// fit the tab on show, rather than padding every tab out to the tallest one.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppearanceSettingsView(model: model)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            HistorySettingsView(model: model)
                .tabItem { Label("History", systemImage: "list.clipboard") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .onAppear {
            model.settings.refreshLaunchAtLogin()
            clearInitialFocus()
        }
    }

    /// Drops keyboard focus when the window opens, so Settings does not appear
    /// with "Remember" selected and one keystroke from being overwritten.
    ///
    /// Retries because the window is not necessarily on screen on the first
    /// pass, and targets the Settings window rather than whatever is key.
    private func clearInitialFocus() {
        for delay in [0.0, 0.1, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                SettingsWindow.current?.makeFirstResponder(nil)
            }
        }
    }
}
