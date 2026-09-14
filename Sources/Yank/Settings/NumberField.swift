import SwiftUI

/// A labelled row with a typeable number field and a stepper.
///
/// The text is committed when editing ends — on return, or when focus leaves —
/// not on every keystroke. Clamping per keystroke makes a value below the
/// lower bound impossible to type: entering `15` into a field with a minimum
/// of `10` would clamp the leading `1` to `10` and end at `105`.
struct NumberField: View {
    let title: LocalizedStringKey
    let suffix: LocalizedStringKey
    let range: ClosedRange<Int>
    let step: Int
    let get: @MainActor () -> Int
    let set: @MainActor (Int) -> Void

    @ViewState private var text = ""
    @FocusState private var isEditing: Bool

    /// Interprets typed text. Anything unparseable — empty, letters, a partial
    /// minus sign — leaves the value untouched rather than resetting it to
    /// zero.
    nonisolated static func parse(_ text: String,
                                  into range: ClosedRange<Int>,
                                  fallingBackTo current: Int) -> Int {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)) else { return current }
        return value.clamped(to: range)
    }

    var body: some View {
        let value = get()

        LabeledContent(title) {
            HStack(spacing: SettingsMetrics.controlSpacing) {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: SettingsMetrics.numberFieldWidth)
                    .focused($isEditing)
                    .onSubmit(commit)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text(verbatim: "\(value)"))

                Stepper("", value: stepper, in: range, step: step)
                    .labelsHidden()

                Text(suffix).foregroundStyle(.secondary)
            }
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { _, new in
            // Reflect changes made elsewhere — the stepper, or Reset — but not
            // while the user is mid-edit.
            if !isEditing { text = String(new) }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commit() }
        }
    }

    /// The stepper writes straight through; its values are in range by
    /// construction.
    private var stepper: Binding<Int> {
        Binding(get: get, set: { newValue in
            let clamped = newValue.clamped(to: range)
            set(clamped)
            text = String(clamped)
        })
    }

    private func commit() {
        let committed = Self.parse(text, into: range, fallingBackTo: get())
        set(committed)
        text = String(committed)
    }
}
