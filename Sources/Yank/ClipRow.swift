import SwiftUI

/// One clip in the dropdown: preview text, hover highlight, ⌘N hint, delete.
struct ClipRow: View {

    let clip: Clip
    /// Zero-based position in the visible list — searching renumbers the
    /// shortcuts along with the rows.
    let index: Int
    let density: RowDensity
    let showShortcut: Bool
    let showSource: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @ViewState private var isHovering = false

    // MARK: - Derived

    /// ⌘1…⌘9 for the first nine rows, ⌘0 for the tenth; nothing beyond.
    ///
    /// Menu-scoped, not global hotkeys — those would need the Accessibility
    /// permission. Static so the mapping can be tested without a view.
    nonisolated static func shortcut(forIndex index: Int)
        -> (key: KeyEquivalent, label: String)? {
        switch index {
        case 0..<9:
            let number = index + 1
            return (KeyEquivalent(Character("\(number)")), "⌘\(number)")
        case 9:
            return (KeyEquivalent("0"), "⌘0")
        default:
            return nil
        }
    }

    private var shortcut: (key: KeyEquivalent, label: String)? {
        Self.shortcut(forIndex: index)
    }

    private var sourceName: String? {
        guard showSource, let bundleID = clip.sourceBundleID else { return nil }
        return AppNameCache.shared.displayName(forBundleID: bundleID)
    }

    /// Hover fills the row with the accent colour, so its labels switch to
    /// white. Each label sets its own colour: a `foregroundStyle` on the parent
    /// is overridden by any child that sets one.
    private var primaryColor: Color { isHovering ? .white : .primary }
    private var secondaryColor: Color { isHovering ? Color.white.opacity(0.75) : .secondary }

    // MARK: - Body

    var body: some View {
        let row = Button(action: onSelect) {
            HStack(spacing: Metrics.rowContentSpacing) {
                Text(clip.singleLinePreview)
                    .font(.system(size: density.fontSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(primaryColor)

                // The enclosing HStack already applies rowContentSpacing.
                Spacer(minLength: 0)

                trailingAccessory
            }
            .padding(.horizontal, Metrics.rowPadding)
            .frame(height: density.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rowCorner)
                    .fill(isHovering ? Color.accentColor : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(clip.shapeDescription)
        .accessibilityLabel(Text(clip.singleLinePreview))
        .accessibilityValue(Text(clip.shapeDescription))
        .accessibilityHint(Text("Puts this clip on the clipboard"))

        // keyboardShortcut takes a non-optional key, so this cannot be one
        // conditional modifier.
        if showShortcut, let shortcut {
            row.keyboardShortcut(shortcut.key, modifiers: .command)
        } else {
            row
        }
    }

    /// Hovering swaps the right-hand label for a delete button; the shortcut
    /// hint is redundant while the pointer is on the row.
    @ViewBuilder
    private var trailingAccessory: some View {
        if isHovering {
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: density.fontSize))
                    .foregroundStyle(secondaryColor)
            }
            .buttonStyle(.plain)
            .help("Delete this clip")
            .accessibilityLabel(Text("Delete clip"))
        } else {
            HStack(spacing: Metrics.rowContentSpacing) {
                if let sourceName {
                    Text(sourceName)
                        .font(.system(size: density.sourceFontSize))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if showShortcut, let shortcut {
                    Text(shortcut.label)
                        .font(.system(size: density.shortcutFontSize))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
    }
}
