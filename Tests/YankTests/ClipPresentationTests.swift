import Foundation
import Testing
@testable import Yank

/// Labels and selection arithmetic for the History tab.
@Suite("ClipPresentation")
struct ClipPresentationTests {

    // MARK: Count label

    @Test("a plain count is singular or plural as appropriate")
    func plainCount() {
        #expect(ClipPresentation.countLabel(total: 1, filtered: 1, selected: 0) == "1 clip")
        #expect(ClipPresentation.countLabel(total: 7, filtered: 7, selected: 0) == "7 clips")
        #expect(ClipPresentation.countLabel(total: 0, filtered: 0, selected: 0) == "0 clips")
    }

    @Test("a filtered view says how many of the total are shown")
    func filteredCount() {
        #expect(ClipPresentation.countLabel(total: 9, filtered: 2, selected: 0) == "2 of 9 shown")
    }

    @Test("a selection outranks the filter count")
    func selectionCount() {
        #expect(ClipPresentation.countLabel(total: 9, filtered: 2, selected: 3)
                == "3 of 9 selected")
    }

    // MARK: Selection pruning

    @Test("ids for clips that no longer exist are dropped")
    func prunesStaleSelection() {
        let kept = Clip(text: "kept")
        let gone = Clip(text: "gone")

        let live = ClipPresentation.liveSelection([kept.id, gone.id], in: [kept])

        #expect(live == [kept.id])
    }

    @Test("an empty history leaves an empty selection")
    func prunesEverything() {
        #expect(ClipPresentation.liveSelection([Clip(text: "x").id], in: []).isEmpty)
    }

    @Test("a selection of live clips is untouched")
    func keepsLiveSelection() {
        let a = Clip(text: "a"), b = Clip(text: "b")
        #expect(ClipPresentation.liveSelection([a.id, b.id], in: [a, b]) == [a.id, b.id])
    }

    // MARK: Subtitle

    @Test("the source app is included when known")
    func subtitleWithApp() {
        let clip = Clip(text: "one\ntwo")
        let subtitle = ClipPresentation.subtitle(for: clip, appName: "Safari")

        #expect(subtitle.contains("Safari"))
        #expect(subtitle.contains(clip.shapeDescription))
    }

    @Test("an unknown source app is omitted rather than shown blank")
    func subtitleWithoutApp() {
        let clip = Clip(text: "one")
        let subtitle = ClipPresentation.subtitle(for: clip, appName: nil)

        #expect(subtitle.hasSuffix(clip.shapeDescription))
        #expect(subtitle.contains(" ·  · ") == false)
    }
}
