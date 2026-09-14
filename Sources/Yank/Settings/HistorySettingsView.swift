import SwiftUI

/// Browse everything Yank has stored, and delete individually or in bulk.
///
/// The dropdown is capped at the display count; this tab shows the full
/// history, which is the only place a clip past that cap can be reached.
struct HistorySettingsView: View {
    let model: AppModel

    @ViewState private var selection = Set<Clip.ID>()
    @ViewState private var query = ""

    var body: some View {
        // Resolved once: the list, the count label and the toolbar all need it.
        let filtered = filteredClips()
        let live = liveSelection

        VStack(spacing: 0) {
            searchField
            Divider()
            if let error = model.store.saveError {
                warningStrip(error)
                Divider()
            }
            list(filtered)
            Divider()
            toolbar(showing: filtered.count, selected: live)
        }
        .frame(width: SettingsMetrics.historyWidth, height: SettingsMetrics.historyHeight)
        .onChange(of: model.store.clips.count) {
            // Clips can vanish from under the selection: evicted by the cap,
            // deleted from the dropdown, or cleared.
            selection = liveSelection
        }
    }

    // MARK: - Derived

    /// The whole history, filtered. Uses the store's own search so this tab
    /// and the dropdown cannot disagree about what matches.
    private func filteredClips() -> [Clip] {
        model.store.visibleClips(matching: query, limit: model.store.clips.count)
    }

    /// The selection, minus any clip that has since been removed.
    private var liveSelection: Set<Clip.ID> {
        ClipPresentation.liveSelection(selection, in: model.store.clips)
    }

    // MARK: - Pieces

    private var searchField: some View {
        HStack(spacing: SettingsMetrics.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: SettingsMetrics.captionFontSize))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search all clips", text: $query)
                .textFieldStyle(.plain)
                .accessibilityLabel(Text("Search all clips"))
        }
        .padding(.horizontal, SettingsMetrics.contentPadding)
        .padding(.vertical, SettingsMetrics.barVerticalPadding)
    }

    private func warningStrip(_ text: String) -> some View {
        HStack(spacing: SettingsMetrics.iconSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            // Verbatim: this is a system error description, not a key.
            Text(verbatim: text)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: SettingsMetrics.captionFontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsMetrics.contentPadding)
        .padding(.vertical, SettingsMetrics.barVerticalPadding)
    }

    @ViewBuilder
    private func list(_ filtered: [Clip]) -> some View {
        if model.store.clips.isEmpty {
            centred(Text("No clips stored yet."))
        } else if filtered.isEmpty {
            centred(Text("No clips match “\(query)”."))
        } else {
            List(selection: $selection) {
                ForEach(filtered) { clip in
                    // Resolved once: it was being built twice per row, once for
                    // the label and once for the accessibility value.
                    let subtitle = subtitle(for: clip)

                    VStack(alignment: .leading, spacing: SettingsMetrics.listRowLineSpacing) {
                        Text(clip.singleLinePreview)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(verbatim: subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, SettingsMetrics.listRowVerticalPadding)
                    .tag(clip.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: clip.singleLinePreview))
                    .accessibilityValue(Text(verbatim: subtitle))
                }
            }
            .alternatingRowBackgrounds()
            .contextMenu(forSelectionType: Clip.ID.self) { ids in
                // The pasteboard holds one value, so a multi-selection has no
                // sensible answer.
                if ids.count == 1,
                   let clip = model.store.clips.first(where: { $0.id == ids.first }) {
                    Button("Copy to Clipboard") { model.apply(clip) }
                }
                Button(ids.count == 1
                       ? String(localized: "Delete", defaultValue: "Delete")
                       : String(format: String(localized: "delete.many",
                                               defaultValue: "Delete %lld Clips"), ids.count),
                       role: .destructive) {
                    delete(ids)
                }
            }
        }
    }

    private func centred(_ text: Text) -> some View {
        VStack {
            Spacer()
            text.foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func toolbar(showing filteredCount: Int, selected: Set<Clip.ID>) -> some View {
        HStack {
            Text(countLabel(showing: filteredCount, selected: selected))
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Delete Selected") { delete(selected) }
                .disabled(selected.isEmpty)

            Button("Clear All") {
                model.store.clearAll()
                selection.removeAll()
            }
            .disabled(model.store.clips.isEmpty)
        }
        .padding(.horizontal, SettingsMetrics.contentPadding)
        .padding(.vertical, SettingsMetrics.toolbarVerticalPadding)
    }

    // MARK: - Actions

    private func delete(_ ids: Set<Clip.ID>) {
        model.store.delete(ids: ids)
        selection.subtract(ids)
    }

    // MARK: - Labels

    private func countLabel(showing filteredCount: Int, selected: Set<Clip.ID>) -> String {
        ClipPresentation.countLabel(total: model.store.clips.count,
                                    filtered: filteredCount,
                                    selected: selected.count)
    }

    private func subtitle(for clip: Clip) -> String {
        let appName = clip.sourceBundleID
            .flatMap { AppNameCache.shared.displayName(forBundleID: $0) }
        return ClipPresentation.subtitle(for: clip, appName: appName)
    }
}
