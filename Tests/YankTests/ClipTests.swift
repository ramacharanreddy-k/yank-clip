import Foundation
import Testing
@testable import Yank

/// Derived fields, equality, and what reaches disk.
@Suite("Clip")
struct ClipTests {

    @Test("newlines collapse to a single line")
    func preview() {
        let clip = Clip(text: "first line\n  second line  \n\n\tthird")
        #expect(clip.singleLinePreview == "first line second line third")
    }

    @Test("blank-only lines are dropped from the preview")
    func previewDropsBlankLines() {
        #expect(Clip(text: "\n\n  \nhello\n \n").singleLinePreview == "hello")
    }

    @Test("very long text is not scanned end to end for the preview")
    func previewIsBounded() {
        let clip = Clip(text: String(repeating: "x", count: 100_000))
        // Bounded to the preview limit, not the full 100k.
        #expect(clip.singleLinePreview.count < 1_000)
    }

    @Test("a preview is still produced when the text opens with blank lines")
    func previewFallsBackPastLeadingBlankLines() {
        // Longer than the bounded prefix, so the fast path yields nothing.
        let clip = Clip(text: String(repeating: "\n", count: 500) + "the actual content")
        #expect(clip.singleLinePreview == "the actual content")
    }

    @Test("shape description reports characters, and lines only when plural")
    func shape() {
        #expect(Clip(text: "a").shapeDescription == "1 character")
        #expect(Clip(text: "abc").shapeDescription == "3 characters")
        #expect(Clip(text: "a\nb").shapeDescription == "2 lines · 3 characters")
    }

    @Test("equality is decided by the persisted fields alone")
    func equalityIgnoresDerivedFields() {
        let id = UUID()
        let when = Date()
        let a = Clip(id: id, text: "same", createdAt: when, sourceBundleID: "x")
        let b = Clip(id: id, text: "same", createdAt: when, sourceBundleID: "x")
        let different = Clip(id: id, text: "other", createdAt: when, sourceBundleID: "x")

        #expect(a == b)
        #expect(a != different)
    }

    @Test("survives a JSON round trip")
    func codableRoundTrip() throws {
        let original = Clip(text: "round trip\nplease", sourceBundleID: "com.example.app")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601

        let restored = try decoder.decode(Clip.self, from: encoder.encode(original))

        #expect(restored.id == original.id)
        #expect(restored.text == original.text)
        #expect(restored.sourceBundleID == original.sourceBundleID)
        #expect(restored.singleLinePreview == original.singleLinePreview)
        #expect(restored.shapeDescription == original.shapeDescription)
    }

    @Test("derived fields are not written to disk")
    func derivedFieldsAreNotPersisted() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Clip(text: "hello", sourceBundleID: "com.example.app"))
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Swift omits nil optionals, so this asserts the four real fields are
        // present and the derived ones never are.
        #expect(Set(object.keys) == ["id", "text", "createdAt", "sourceBundleID"])
        #expect(object["singleLinePreview"] == nil)
        #expect(object["shapeDescription"] == nil)
    }

    @Test("a missing sourceBundleID decodes as nil rather than failing")
    func decodesWithoutSourceBundleID() throws {
        let json = #"{"id":"\#(UUID().uuidString)","text":"hi","createdAt":"2026-09-13T22:00:00Z"}"#
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601

        let clip = try decoder.decode(Clip.self, from: Data(json.utf8))

        #expect(clip.sourceBundleID == nil)
        #expect(clip.text == "hi")
    }
}
