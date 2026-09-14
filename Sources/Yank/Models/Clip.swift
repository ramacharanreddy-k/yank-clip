import Foundation

/// One captured clipboard entry.
///
/// `singleLinePreview` and `shapeDescription` are derived from `text` but
/// stored, not computed: `String.count` walks grapheme clusters, and as
/// computed properties they would run on every render of every visible row.
/// Neither is persisted — `CodingKeys` lists only the four real fields and the
/// decoder re-derives them.
struct Clip: Identifiable, Codable, Equatable {

    let id: UUID
    let text: String
    let createdAt: Date

    /// Bundle ID of the app frontmost at capture time. Off by default in the
    /// UI, but recorded because it cannot be recovered later.
    let sourceBundleID: String?

    /// Newlines collapsed to spaces, for the one-line menu rows.
    let singleLinePreview: String

    /// "3 lines · 412 characters", shown in tooltips and the History tab.
    let shapeDescription: String

    private enum CodingKeys: String, CodingKey {
        case id, text, createdAt, sourceBundleID
    }

    init(id: UUID = UUID(),
         text: String,
         createdAt: Date = Date(),
         sourceBundleID: String? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
        self.singleLinePreview = Self.makePreview(of: text)
        self.shapeDescription = Self.makeShapeDescription(of: text)
    }

    /// Decodes the four persisted fields and re-derives the rest.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(UUID.self, forKey: .id),
                  text: try container.decode(String.self, forKey: .text),
                  createdAt: try container.decode(Date.self, forKey: .createdAt),
                  sourceBundleID: try container.decodeIfPresent(String.self,
                                                                forKey: .sourceBundleID))
    }

    // MARK: - Derivation

    /// Rows truncate after a few dozen characters, so collapsing more than
    /// this is wasted work.
    private static let previewCharacterLimit = 300

    private static func makePreview(of text: String) -> String {
        let collapsed = collapse(text.prefix(previewCharacterLimit))
        guard collapsed.isEmpty else { return collapsed }

        // The prefix was all whitespace — text opening with a long run of
        // blank lines. A full scan is the cost of not rendering a blank row.
        return collapse(Substring(text))
    }

    private static func collapse(_ text: Substring) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func makeShapeDescription(of text: String) -> String {
        let lineCount = text.split(whereSeparator: \.isNewline).count
        let characterCount = text.count
        let characters = characterCount == 1
            ? String(localized: "characters.one", defaultValue: "1 character")
            : String(format: String(localized: "characters.many",
                                    defaultValue: "%lld characters"), characterCount)
        guard lineCount > 1 else { return characters }
        return String(format: String(localized: "lines.and.characters",
                                     defaultValue: "%1$lld lines · %2$@"),
                      lineCount, characters)
    }

    // MARK: - Equatable

    /// Compares only the persisted fields. The derived ones are functions of
    /// `text`, so equal text already implies they match.
    static func == (lhs: Clip, rhs: Clip) -> Bool {
        lhs.id == rhs.id
            && lhs.text == rhs.text
            && lhs.createdAt == rhs.createdAt
            && lhs.sourceBundleID == rhs.sourceBundleID
    }

}
