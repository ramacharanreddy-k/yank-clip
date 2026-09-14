import Testing
@testable import Yank

/// The density table. `MenuContent` computes the panel height from these, so a
/// wrong value here is a wrong-sized menu.
@Suite("RowDensity")
struct RowDensityTests {

    @Test("every case has a distinct, non-empty title")
    func titles() {
        let titles = RowDensity.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == RowDensity.allCases.count)
    }

    @Test("rows get taller from compact to roomy")
    func heightsIncrease() {
        #expect(RowDensity.compact.rowHeight < RowDensity.comfortable.rowHeight)
        #expect(RowDensity.comfortable.rowHeight < RowDensity.roomy.rowHeight)
    }

    @Test("text gets larger from compact to roomy")
    func fontSizesIncrease() {
        #expect(RowDensity.compact.fontSize < RowDensity.comfortable.fontSize)
        #expect(RowDensity.comfortable.fontSize < RowDensity.roomy.fontSize)
    }

    @Test("secondary text is smaller than the clip text, in every density")
    func secondaryTextIsSubordinate() {
        for density in RowDensity.allCases {
            #expect(density.sourceFontSize < density.fontSize)
            #expect(density.shortcutFontSize < density.fontSize)
            // The shortcut stays the more legible of the two.
            #expect(density.sourceFontSize < density.shortcutFontSize)
        }
    }

    @Test("text always fits inside the row it is drawn in")
    func textFitsTheRow() {
        for density in RowDensity.allCases {
            #expect(density.fontSize < density.rowHeight)
        }
    }

    @Test("raw values round-trip, so a stored preference survives a relaunch")
    func rawValueRoundTrip() {
        for density in RowDensity.allCases {
            #expect(RowDensity(rawValue: density.rawValue) == density)
        }
        #expect(RowDensity(rawValue: "nonsense") == nil)
    }

    @Test("the id matches the raw value, so Picker selection persists correctly")
    func identity() {
        for density in RowDensity.allCases {
            #expect(density.id == density.rawValue)
        }
    }
}
