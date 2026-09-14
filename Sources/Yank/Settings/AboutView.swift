import SwiftUI
import AppKit

/// Identity, where history lives on disk, and links back to the repo.
struct AboutView: View {

    private var storagePath: String {
        ClipStore.defaultStoreURL.path(percentEncoded: false)
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: SettingsMetrics.aboutHeaderSpacing) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: SettingsMetrics.appIconSize, height: SettingsMetrics.appIconSize)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SettingsMetrics.aboutLineSpacing) {
                    Text(AppInfo.name)
                        .font(.system(size: SettingsMetrics.appNameFontSize, weight: .bold))
                    Text(AppInfo.version)
                        .foregroundStyle(.secondary)
                    Text(AppInfo.tagline)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(AppInfo.licence)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, SettingsMetrics.aboutLicenceTopPadding)
                }
                Spacer(minLength: 0)
            }
            .padding(SettingsMetrics.aboutPadding)

            Divider()

            VStack(alignment: .leading, spacing: SettingsMetrics.aboutSectionSpacing) {
                LabeledContent("History file") {
                    HStack(spacing: SettingsMetrics.aboutRowSpacing) {
                        Text(storagePath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Show") {
                            NSWorkspace.shared
                                .activateFileViewerSelecting([ClipStore.defaultStoreURL])
                        }
                        .accessibilityLabel(Text("Show the history file in Finder"))
                    }
                }
                Text("Stored on this Mac only, readable by your account alone.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, SettingsMetrics.aboutPadding)
            .padding(.vertical, SettingsMetrics.aboutSectionVerticalPadding)

            Spacer(minLength: 0)

            Divider()

            HStack(spacing: SettingsMetrics.aboutButtonSpacing) {
                Button("GitHub") {
                    NSWorkspace.shared.open(AppInfo.repository)
                }
                Button("Report an Issue") {
                    NSWorkspace.shared.open(AppInfo.issues)
                }
                Spacer()
                Text(AppInfo.copyright)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, SettingsMetrics.aboutPadding)
            .padding(.vertical, SettingsMetrics.aboutFooterVerticalPadding)
        }
        .frame(width: SettingsMetrics.width, height: SettingsMetrics.aboutHeight)
    }
}
