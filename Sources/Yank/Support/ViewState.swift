import SwiftUI

/// A stand-in for `@State`, with identical behaviour and `$binding`.
///
/// The macOS 26/27 SDK declares `State` both as a property wrapper and as a
/// macro, and the compiler prefers the macro. Its plugin ships only with Xcode,
/// so on a Command Line Tools toolchain `@State` fails to compile:
///
///     error: external macro implementation type 'SwiftUIMacros.StateMacro'
///            could not be found for macro 'State()'
///
/// The underlying `State` struct is unaffected; wrapping it in a
/// `DynamicProperty`, which SwiftUI recurses into, restores the behaviour.
///
/// With Xcode installed this file can be deleted and `@ViewState` replaced with
/// `@State`. Nothing else depends on it.
@propertyWrapper
struct ViewState<Value>: DynamicProperty {
    private var storage: State<Value>

    init(wrappedValue: Value) {
        storage = State(initialValue: wrappedValue)
    }

    var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> {
        storage.projectedValue
    }
}
