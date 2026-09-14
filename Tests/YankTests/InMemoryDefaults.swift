import Foundation

/// A `UserDefaults` that never touches disk.
///
/// `UserDefaults(suiteName:)` writes a plist into ~/Library/Preferences, and
/// `removePersistentDomain(forName:)` clears the values but leaves the file
/// behind. Keeping everything in memory leaves no trace and needs no teardown.
final class InMemoryDefaults: UserDefaults {

    private var storage: [String: Any] = [:]
    private var registered: [String: Any] = [:]

    override func register(defaults registrationDictionary: [String: Any]) {
        registered.merge(registrationDictionary) { _, new in new }
    }

    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName] ?? registered[defaultName]
    }

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }

    // Each primitive has its own overload rather than routing through
    // set(_: Any?, forKey:), so all of them need intercepting.
    override func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    override func set(_ value: Int, forKey defaultName: String) { storage[defaultName] = value }
    override func set(_ value: Bool, forKey defaultName: String) { storage[defaultName] = value }
    override func set(_ value: Double, forKey defaultName: String) { storage[defaultName] = value }
    override func set(_ value: Float, forKey defaultName: String) { storage[defaultName] = value }

    override func integer(forKey defaultName: String) -> Int {
        object(forKey: defaultName) as? Int ?? 0
    }

    override func bool(forKey defaultName: String) -> Bool {
        object(forKey: defaultName) as? Bool ?? false
    }

    override func double(forKey defaultName: String) -> Double {
        if let value = object(forKey: defaultName) as? Double { return value }
        if let value = object(forKey: defaultName) as? Int { return Double(value) }
        return 0
    }

    override func string(forKey defaultName: String) -> String? {
        object(forKey: defaultName) as? String
    }
}
