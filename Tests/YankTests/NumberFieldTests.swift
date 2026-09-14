import Testing
@testable import Yank

/// Parsing and clamping of typed input. Committing on edit-end rather than per
/// keystroke is what makes a two-digit entry possible at all.
@Suite("NumberField")
struct NumberFieldTests {

    private let range = 10...1000

    @Test("a value inside the range is taken as typed")
    func acceptsValid() {
        #expect(NumberField.parse("250", into: range, fallingBackTo: 1) == 250)
    }

    @Test("a two-digit entry is not mangled by a per-keystroke clamp")
    func twoDigitEntry() {
        // The whole reason parsing happens on commit: clamping "1" first would
        // yield 10, and the following "5" would make 105.
        #expect(NumberField.parse("15", into: range, fallingBackTo: 200) == 15)
    }

    @Test("values outside the range are clamped to the nearest bound")
    func clampsOutOfRange() {
        #expect(NumberField.parse("0", into: range, fallingBackTo: 1) == 10)
        #expect(NumberField.parse("-5", into: range, fallingBackTo: 1) == 10)
        #expect(NumberField.parse("99999", into: range, fallingBackTo: 1) == 1000)
    }

    @Test("the bounds themselves are accepted unchanged")
    func acceptsBounds() {
        #expect(NumberField.parse("10", into: range, fallingBackTo: 1) == 10)
        #expect(NumberField.parse("1000", into: range, fallingBackTo: 1) == 1000)
    }

    @Test("unparseable text leaves the current value alone",
          arguments: ["", "   ", "abc", "-", "1.5", "12x"])
    func keepsCurrentValueOnGarbage(_ text: String) {
        #expect(NumberField.parse(text, into: range, fallingBackTo: 200) == 200)
    }

    @Test("surrounding whitespace is ignored")
    func trimsWhitespace() {
        #expect(NumberField.parse("  42  ", into: range, fallingBackTo: 1) == 42)
    }
}
