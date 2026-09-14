import CoreGraphics

/// Layout constants for the dropdown.
///
/// Collected because they have to agree: `MenuContent` computes the panel
/// height from the row height and spacing `ClipRow` draws with.
enum Metrics {

    // MARK: Rows

    /// Gap between rows; part of the height calculation.
    static let rowSpacing: CGFloat = 1
    /// Horizontal padding inside a row.
    static let rowPadding: CGFloat = 10
    /// Corner radius of the hover highlight.
    static let rowCorner: CGFloat = 5
    /// Gap between a row's text and its trailing accessory.
    static let rowContentSpacing: CGFloat = 8

    // MARK: List

    /// Inset of the row stack inside the scroll view.
    static let listInset: CGFloat = 6
    /// Vertical padding above and below the row stack.
    static let listPadding: CGFloat = 5
    /// Room reserved for the search field, footer and menu bar when deciding
    /// how tall the list may grow.
    static let panelChrome: CGFloat = 200
    /// Assumed screen height when `NSScreen.main` is unavailable.
    static let assumedScreenHeight: CGFloat = 900
    /// Floor for the list height, so an empty state cannot collapse the panel.
    static let minimumListHeight: CGFloat = 300

    // MARK: Bars

    /// Horizontal padding for the search field and footer.
    static let barHorizontalPadding: CGFloat = 12
    /// Vertical padding for the search field and footer.
    static let barVerticalPadding: CGFloat = 9
    /// Gap between the footer's buttons.
    static let footerSpacing: CGFloat = 14
    /// Gap between an icon and the text beside it.
    static let iconSpacing: CGFloat = 7
    /// Vertical padding for the empty and error states.
    static let messagePadding: CGFloat = 16

    // MARK: Type

    /// Body text size in the dropdown.
    static let fontSize: CGFloat = 13
    /// Secondary text — icons beside fields, warning strips.
    static let captionFontSize: CGFloat = 12
}
