import SwiftUI

/// Customisation for the dropdown: how wide it is, how tall its rows are, and
/// what each row shows besides the clip text.
struct AppearanceSettingsView: View {
    let model: AppModel

    private var settings: AppSettings { model.settings }

    var body: some View {
        Form {
            Section("Menu") {
                LabeledContent("Width") {
                    HStack(spacing: SettingsMetrics.sliderSpacing) {
                        Slider(value: Binding(get: { settings.menuWidth },
                                              set: { settings.menuWidth = $0 }),
                               in: AppSettings.Limits.menuWidth, step: AppSettings.Steps.menuWidth)
                            .accessibilityLabel(Text("Menu width"))
                            .accessibilityValue(Text("\(Int(settings.menuWidth)) points"))
                        Text("\(Int(settings.menuWidth)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: SettingsMetrics.sliderReadoutWidth, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }

                Picker("Row height", selection: Binding(get: { settings.rowDensity },
                                                        set: { settings.rowDensity = $0 })) {
                    ForEach(RowDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Rows") {
                Toggle("Show keyboard shortcuts (⌘1–⌘0)", isOn: Binding(
                    get: { settings.showShortcutHints },
                    set: { settings.showShortcutHints = $0 }
                ))
                Toggle("Show the app each clip came from", isOn: Binding(
                    get: { settings.showSourceApp },
                    set: { settings.showSourceApp = $0 }
                ))
            }

            Section {
                HStack {
                    Text("Changes apply the next time you open the menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: SettingsMetrics.captionGap)
                    Button("Reset to Defaults") { settings.resetAppearance() }
                        .disabled(settings.appearanceIsDefault)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.width, height: SettingsMetrics.appearanceHeight)
    }
}
