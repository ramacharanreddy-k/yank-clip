import Testing
@testable import Yank

/// The ⌘N mapping. Its boundary sits between the tenth and eleventh row.
@Suite("ClipRow shortcuts")
struct ClipRowTests {

    @Test("the first nine rows take ⌘1 through ⌘9")
    func firstNine() {
        for index in 0..<9 {
            #expect(ClipRow.shortcut(forIndex: index)?.label == "⌘\(index + 1)")
        }
    }

    @Test("the tenth row takes ⌘0, continuing the keyboard's own order")
    func tenth() {
        #expect(ClipRow.shortcut(forIndex: 9)?.label == "⌘0")
    }

    @Test("rows past the tenth have no shortcut")
    func beyondTenth() {
        #expect(ClipRow.shortcut(forIndex: 10) == nil)
        #expect(ClipRow.shortcut(forIndex: 99) == nil)
    }

    @Test("a negative index is refused rather than crashing")
    func negativeIndex() {
        #expect(ClipRow.shortcut(forIndex: -1) == nil)
    }
}
