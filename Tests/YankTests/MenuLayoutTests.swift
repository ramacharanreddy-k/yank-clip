import CoreGraphics
import Testing
@testable import Yank

/// Panel height arithmetic. A zero here once collapsed the list to a sliver.
@Suite("MenuLayout")
struct MenuLayoutTests {

    private func height(rows: Int, maximum: Double = 10_000) -> Double {
        MenuLayout.listHeight(rowCount: rows, rowHeight: 28, spacing: 1,
                              padding: 5, maxHeight: maximum)
    }

    @Test("one row is one row plus padding")
    func singleRow() {
        #expect(height(rows: 1) == 28 + 10)
    }

    @Test("rows accumulate with spacing between them, not after the last")
    func manyRows() {
        #expect(height(rows: 10) == 10 * 28 + 9 * 1 + 10)
    }

    @Test("zero rows never collapses the panel")
    func zeroRows() {
        // Reserves a single row: an empty list must not render as a sliver.
        #expect(height(rows: 0) == height(rows: 1))
        #expect(height(rows: 0) > 0)
    }

    @Test("the maximum is respected once there are enough rows")
    func capped() {
        #expect(height(rows: 500, maximum: 400) == 400)
    }

    @Test("taller rows produce a taller panel")
    func densityAffectsHeight() {
        let compact = MenuLayout.listHeight(rowCount: 10, rowHeight: 24, spacing: 1,
                                            padding: 5, maxHeight: 10_000)
        let roomy = MenuLayout.listHeight(rowCount: 10, rowHeight: 34, spacing: 1,
                                          padding: 5, maxHeight: 10_000)
        #expect(roomy > compact)
    }

    // MARK: Screen fitting

    @Test("the ceiling leaves room for the search field, footer and menu bar")
    func leavesRoomForChrome() {
        #expect(MenuLayout.maxListHeight(screenHeight: 1000)
                == 1000 - Metrics.panelChrome)
    }

    @Test("a missing screen falls back to an assumed height")
    func noScreen() {
        #expect(MenuLayout.maxListHeight(screenHeight: nil)
                == Metrics.assumedScreenHeight - Metrics.panelChrome)
    }

    @Test("a tiny screen still leaves a usable list")
    func tinyScreen() {
        #expect(MenuLayout.maxListHeight(screenHeight: 100) == Metrics.minimumListHeight)
    }
}
