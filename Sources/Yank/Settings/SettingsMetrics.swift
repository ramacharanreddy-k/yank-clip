import CoreGraphics

/// Window sizes for the Settings tabs.
///
/// Each tab sets its own frame so the window resizes to the tab rather than
/// padding every tab out to the tallest one. Collected here so the shared width
/// is stated once — four copies of the same number drifted apart the first time
/// one of them was adjusted.
enum SettingsMetrics {
    /// Shared by every tab except History, which needs room for two-line rows.
    static let width: CGFloat = 460

    static let generalHeight: CGFloat = 340
    static let appearanceHeight: CGFloat = 330
    static let aboutHeight: CGFloat = 348

    /// History is a scrolling list, so it takes a stable, taller window rather
    /// than one that hugs its contents.
    static let historyWidth: CGFloat = 500
    static let historyHeight: CGFloat = 460

    /// Padding around the content of hand-laid-out tabs (History, About).
    static let contentPadding: CGFloat = 14
    static let aboutPadding: CGFloat = 24

    /// Vertical padding for the History tab's search field and toolbar.
    static let barVerticalPadding: CGFloat = 9
    static let toolbarVerticalPadding: CGFloat = 10

    /// Minimum gap between a caption and the control beside it.
    static let captionGap: CGFloat = 12
    /// Gap between an icon and the text beside it.
    static let iconSpacing: CGFloat = 7
    /// Secondary text size, matching the dropdown's caption size.
    static let captionFontSize: CGFloat = 12

    // MARK: Controls

    /// Width of the number field in `NumberField`, wide enough for four digits.
    static let numberFieldWidth: CGFloat = 68
    /// Gap between a number field, its stepper and its unit label.
    static let controlSpacing: CGFloat = 6
    /// Gap between a slider and its readout.
    static let sliderSpacing: CGFloat = 10
    /// Width of the slider's value readout, fixed so the slider does not
    /// resize as the number's width changes.
    static let sliderReadoutWidth: CGFloat = 56
    /// Gap between a clip's preview and its subtitle in the History list.
    static let listRowLineSpacing: CGFloat = 1
    /// Breathing room above and below a two-line History row.
    static let listRowVerticalPadding: CGFloat = 2

    // MARK: About

    static let appIconSize: CGFloat = 96
    static let appNameFontSize: CGFloat = 28
    static let aboutHeaderSpacing: CGFloat = 20
    static let aboutLineSpacing: CGFloat = 5
    static let aboutSectionSpacing: CGFloat = 6
    static let aboutRowSpacing: CGFloat = 8
    static let aboutButtonSpacing: CGFloat = 10
    static let aboutSectionVerticalPadding: CGFloat = 14
    static let aboutFooterVerticalPadding: CGFloat = 12
    /// Separates the licence line from the tagline above it.
    static let aboutLicenceTopPadding: CGFloat = 2
}
