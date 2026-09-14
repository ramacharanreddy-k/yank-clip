/// What the dropdown should show below its search field.
///
/// The choice between these is the single most bug-prone decision in the app,
/// so it lives here as a pure function rather than as branching inside a view
/// body where it cannot be tested.
enum MenuState: Equatable {
    /// Saved history could not be read and there is nothing to fall back on.
    case loadFailed(String)
    /// Recording is on, but nothing has been copied yet.
    case empty
    /// Recording is off and there is no history to show.
    case recordingPaused
    /// There are clips, but none match the search.
    case noMatches(query: String)
    /// The rows to draw.
    case list([Clip])

    /// - Parameters:
    ///   - clips: the full history.
    ///   - visible: `clips` after search and the display cap.
    ///   - loadError: set when history could not be read at launch.
    ///
    /// A *save* failure is deliberately not an input: the clips are in memory
    /// and still usable, so it is shown as a warning alongside whichever state
    /// this returns rather than replacing it.
    static func resolve(clips: [Clip],
                        visible: [Clip],
                        query: String,
                        isRecording: Bool,
                        loadError: String?) -> MenuState {
        if clips.isEmpty {
            if let loadError { return .loadFailed(loadError) }
            return isRecording ? .empty : .recordingPaused
        }
        if visible.isEmpty { return .noMatches(query: query) }
        return .list(visible)
    }
}
