import Foundation

/// Identity strings shown in the UI, in one place rather than inline in views.
enum AppInfo {
    static let name = "Yank"
    static let tagline = String(localized: "app.tagline",
                                defaultValue: "Menu bar clipboard history with instant search.")
    static let licence = String(localized: "app.licence",
                                defaultValue: "MIT licensed · No permissions required")
    static let copyright = "© 2026 Ramacharan Reddy"

    /// Literal, known-valid at compile time.
    static let repository = URL(string: "https://github.com/ramacharanreddy-k/yank-clip")!
    static var issues: URL { repository.appending(path: "issues") }

    /// CFBundleShortVersionString, written into Info.plist by build.sh.
    /// CFBundleVersion is deliberately not shown — it is internal bookkeeping.
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(short)"
    }
}
