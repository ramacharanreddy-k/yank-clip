import CoreGraphics
import Foundation

/// How tall each row in the dropdown is drawn, and how large its text is.
enum RowDensity: String, CaseIterable, Identifiable, Sendable {
    case compact, comfortable, roomy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:     String(localized: "density.compact", defaultValue: "Compact")
        case .comfortable: String(localized: "density.comfortable", defaultValue: "Comfortable")
        case .roomy:       String(localized: "density.roomy", defaultValue: "Roomy")
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .compact:     24
        case .comfortable: 28
        case .roomy:       34
        }
    }

    /// Size of the clip text.
    var fontSize: CGFloat {
        switch self {
        case .compact:     12.5
        case .comfortable: 13
        case .roomy:       14
        }
    }

    /// Size of the source-app label, which sits beside the clip text and should
    /// read as clearly subordinate to it.
    var sourceFontSize: CGFloat { fontSize - 2 }

    /// Size of the ⌘N hint. Only slightly smaller — it has to stay legible at
    /// a glance, which is the whole point of showing it.
    var shortcutFontSize: CGFloat { fontSize - 1 }
}
