import Testing
@testable import Yank

/// The clamping helper the settings setters rely on.
@Suite("Clamping")
struct ClampingTests {

    @Test("a value inside the range is unchanged")
    func inside() {
        #expect(5.clamped(to: 1...10) == 5)
    }

    @Test("values outside are pulled to the nearest bound")
    func outside() {
        #expect(0.clamped(to: 1...10) == 1)
        #expect(99.clamped(to: 1...10) == 10)
        #expect((-50).clamped(to: 1...10) == 1)
    }

    @Test("the bounds are inclusive")
    func bounds() {
        #expect(1.clamped(to: 1...10) == 1)
        #expect(10.clamped(to: 1...10) == 10)
    }

    @Test("a single-value range collapses everything onto it")
    func degenerateRange() {
        #expect(7.clamped(to: 3...3) == 3)
    }

    @Test("it works for any Comparable, not just Int")
    func nonInteger() {
        #expect(0.5.clamped(to: 1.0...2.0) == 1.0)
        #expect("m".clamped(to: "a"..."f") == "f")
    }
}
