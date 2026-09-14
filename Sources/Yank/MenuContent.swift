import SwiftUI
import AppKit

/// The dropdown: search field, clip list, footer.
struct MenuContent: View {

    let model: AppModel

    @ViewState private var query = ""
    @FocusState private var searchFocused: Bool

    private var settings: AppSettings { model.settings }

    var body: some View {
        // Resolved once per render: the list and its height both need it, and
        // filtering the history is not free.
        let visible = model.store.visibleClips(matching: query, limit: settings.displayCount)

        VStack(spacing: 0) {
            searchField
            Divider()
            content(for: visible)
            Divider()
            footer
        }
        .frame(width: settings.menuWidth)
        // The panel must be key before any focus request can land; see
        // PanelKeyFocus. Zero-sized, so it only reaches the window.
        .background(PanelKeyFocus().frame(width: 0, height: 0))
        .defaultFocus($searchFocused, true)
        .onAppear {
            // Asked for after the panel has had a chance to become key.
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: Metrics.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.captionFontSize))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search clips", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.fontSize))
                .focused($searchFocused)
                .accessibilityLabel(Text("Search clips"))

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Metrics.captionFontSize))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, Metrics.barHorizontalPadding)
        .padding(.vertical, Metrics.barVerticalPadding)
    }

    // MARK: - List

    /// A save failure shows as a strip above the normal content rather than
    /// replacing it: the clips are in memory and still usable.
    @ViewBuilder
    private func content(for visible: [Clip]) -> some View {
        if let error = model.store.saveError {
            VStack(spacing: 0) {
                warningStrip(error)
                Divider()
                listOrPlaceholder(for: visible)
            }
        } else {
            listOrPlaceholder(for: visible)
        }
    }

    /// The rows, or the reason there are none. Separate from `content(for:)`
    /// so the save warning composes with every case, not just the list.
    @ViewBuilder
    private func listOrPlaceholder(for visible: [Clip]) -> some View {
        switch MenuState.resolve(clips: model.store.clips,
                                 visible: visible,
                                 query: query,
                                 isRecording: settings.isRecording,
                                 loadError: model.store.loadError) {
        case .loadFailed(let error):
            // Verbatim: a system error description is not a translatable key.
            message(Text(verbatim: error), systemImage: "exclamationmark.triangle")
        case .empty:
            message(Text("No clips yet. Copy something."), systemImage: "doc.on.clipboard")
        case .recordingPaused:
            message(Text("Recording is paused."), systemImage: "pause.circle")
        case .noMatches(let query):
            message(Text("No clips match “\(query)”."), systemImage: "magnifyingglass")
        case .list(let clips):
            clipList(clips)
        }
    }

    private func clipList(_ visible: [Clip]) -> some View {
        ScrollView {
            LazyVStack(spacing: Metrics.rowSpacing) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, clip in
                    ClipRow(clip: clip,
                            index: index,
                            density: settings.rowDensity,
                            showShortcut: settings.showShortcutHints,
                            showSource: settings.showSourceApp) {
                        model.apply(clip)
                    } onDelete: {
                        model.store.delete(clip)
                    }
                }
            }
            .padding(.horizontal, Metrics.listInset)
            .padding(.vertical, Metrics.listPadding)
        }
        .frame(height: listHeight(rowCount: visible.count))
    }

    /// Non-blocking warning shown above the rows when history is not being
    /// written to disk.
    private func warningStrip(_ text: String) -> some View {
        HStack(spacing: Metrics.iconSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            // Verbatim: this is a system error description, not a key.
            Text(verbatim: text)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: Metrics.captionFontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.barHorizontalPadding)
        .padding(.vertical, Metrics.barVerticalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Warning: \(text)"))
    }

    private func listHeight(rowCount: Int) -> CGFloat {
        MenuLayout.listHeight(
            rowCount: rowCount,
            rowHeight: settings.rowDensity.rowHeight,
            spacing: Metrics.rowSpacing,
            padding: Metrics.listPadding,
            maxHeight: MenuLayout.maxListHeight(screenHeight: NSScreen.main?.visibleFrame.height))
    }

    /// Takes a `Text` rather than a `String`: `Text(aStringVariable)` selects
    /// the non-localising overload, so a literal passed through as a `String`
    /// would never be translated.
    private func message(_ text: Text, systemImage: String) -> some View {
        HStack(spacing: Metrics.iconSpacing) {
            Image(systemName: systemImage)
            text.lineLimit(2)
        }
        .font(.system(size: Metrics.fontSize))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.barHorizontalPadding)
        .padding(.vertical, Metrics.messagePadding)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Metrics.footerSpacing) {
            Button("Clear All") { model.store.clearAll() }
                .disabled(model.store.clips.isEmpty)

            SettingsLink {
                Text("Settings…")
            }
            .simultaneousGesture(TapGesture().onEnded {
                // An accessory app must activate itself or Settings opens
                // behind whatever the user was working in.
                NSApp.activate(ignoringOtherApps: true)
            })

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(.plain)
        .font(.system(size: Metrics.fontSize))
        .padding(.horizontal, Metrics.barHorizontalPadding)
        .padding(.vertical, Metrics.barVerticalPadding)
    }
}
