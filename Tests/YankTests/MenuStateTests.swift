import Testing
@testable import Yank

/// The six outcomes the dropdown chooses between. Two separate bugs have lived
/// in this decision, so every branch is pinned here.
@Suite("MenuState")
struct MenuStateTests {

    private func clip(_ text: String) -> Clip { Clip(text: text) }

    @Test("no clips and a load error reports the error")
    func loadFailure() {
        let state = MenuState.resolve(clips: [], visible: [], query: "",
                                      isRecording: true, loadError: "disk is on fire")
        #expect(state == .loadFailed("disk is on fire"))
    }

    @Test("no clips while recording invites a copy")
    func emptyWhileRecording() {
        let state = MenuState.resolve(clips: [], visible: [], query: "",
                                      isRecording: true, loadError: nil)
        #expect(state == .empty)
    }

    @Test("no clips while paused says so, rather than inviting a copy")
    func emptyWhilePaused() {
        let state = MenuState.resolve(clips: [], visible: [], query: "",
                                      isRecording: false, loadError: nil)
        #expect(state == .recordingPaused)
    }

    @Test("clips that do not match the search report no matches")
    func noMatches() {
        let state = MenuState.resolve(clips: [clip("a")], visible: [], query: "zzz",
                                      isRecording: true, loadError: nil)
        #expect(state == .noMatches(query: "zzz"))
    }

    @Test("matching clips are listed")
    func list() {
        let clips = [clip("a"), clip("b")]
        let state = MenuState.resolve(clips: clips, visible: clips, query: "",
                                      isRecording: true, loadError: nil)
        #expect(state == .list(clips))
    }

    // MARK: Precedence

    @Test("a load error does not hide clips that were recovered anyway")
    func loadErrorYieldsToPresentClips() {
        let clips = [clip("recovered")]
        let state = MenuState.resolve(clips: clips, visible: clips, query: "",
                                      isRecording: true, loadError: "partial read")
        #expect(state == .list(clips))
    }

    @Test("a search that matches nothing is reported even while paused")
    func noMatchesOutranksPaused() {
        let state = MenuState.resolve(clips: [clip("a")], visible: [], query: "q",
                                      isRecording: false, loadError: nil)
        #expect(state == .noMatches(query: "q"))
    }

    @Test("the paused state only applies when there is nothing to show")
    func pausedOnlyWhenEmpty() {
        let clips = [clip("a")]
        let state = MenuState.resolve(clips: clips, visible: clips, query: "",
                                      isRecording: false, loadError: nil)
        #expect(state == .list(clips))
    }
}
