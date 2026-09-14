import SwiftUI

/// How much history to keep, how much of it to show, and whether to record
/// at all.
struct GeneralSettingsView: View {
    let model: AppModel

    private var settings: AppSettings { model.settings }

    var body: some View {
        Form {
            Section("Clips") {
                NumberField(title: "Remember",
                            suffix: "clips",
                            range: AppSettings.Limits.rememberCount,
                            step: AppSettings.Steps.rememberCount,
                            value: Binding(get: { settings.rememberCount },
                                           set: { settings.rememberCount = $0 }))

                NumberField(title: "Show in menu",
                            suffix: "clips",
                            range: AppSettings.Limits.displayCount,
                            step: AppSettings.Steps.displayCount,
                            value: Binding(get: { settings.displayCount },
                                           set: { settings.displayCount = $0 }))
            }

            Section("Options") {
                Toggle("Record clipboard history", isOn: Binding(
                    get: { settings.isRecording },
                    set: { settings.isRecording = $0 }
                ))
                Toggle("Launch Yank at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Text("""
                     Yank asks for no permissions. Reading the clipboard is \
                     unprivileged, and copies that apps mark as concealed — \
                     password managers do this — are never recorded.
                     """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.width, height: SettingsMetrics.generalHeight)
    }
}
