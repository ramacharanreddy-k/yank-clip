import CoreGraphics

/// Height arithmetic for the dropdown's clip list.
///
/// A `ScrollView` has no intrinsic height: given only a `maxHeight` it shrinks
/// to whatever the parent proposes, which inside a menu bar window is close to
/// nothing. The panel is therefore given an explicit height derived from the
/// row count.
enum MenuLayout {

    /// Tall enough for `rowCount` rows, capped at `maxHeight`.
    ///
    /// Never returns less than one row's worth, so an unexpected zero cannot
    /// collapse the panel into a sliver.
    static func listHeight(rowCount: Int,
                           rowHeight: CGFloat,
                           spacing: CGFloat,
                           padding: CGFloat,
                           maxHeight: CGFloat) -> CGFloat {
        let rows = max(1, rowCount)
        let content = CGFloat(rows) * rowHeight + CGFloat(rows - 1) * spacing
        return min(content + padding * 2, maxHeight)
    }

    /// The tallest the list may grow, given the usable height of the screen.
    static func maxListHeight(screenHeight: CGFloat?) -> CGFloat {
        let usable = screenHeight ?? Metrics.assumedScreenHeight
        return max(Metrics.minimumListHeight, usable - Metrics.panelChrome)
    }
}
