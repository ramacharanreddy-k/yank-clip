import Foundation
import Testing
@testable import Yank

/// Identity strings and the links the About tab opens.
@Suite("AppInfo")
struct AppInfoTests {

    @Test("the identity strings are present")
    func strings() {
        #expect(AppInfo.name == "Yank")
        #expect(!AppInfo.tagline.isEmpty)
        #expect(!AppInfo.licence.isEmpty)
        #expect(!AppInfo.copyright.isEmpty)
    }

    @Test("the repository link is a resolvable https URL")
    func repositoryURL() {
        #expect(AppInfo.repository.scheme == "https")
        #expect(AppInfo.repository.host() == "github.com")
    }

    @Test("the issues link is derived from the repository, not typed twice")
    func issuesURL() {
        #expect(AppInfo.issues.absoluteString == AppInfo.repository.absoluteString + "/issues")
    }

    @Test("the version reads as a version, with a fallback outside a bundle")
    func version() {
        // Running under the test harness there is no app bundle, so this
        // exercises the fallback path rather than Info.plist.
        #expect(AppInfo.version.hasPrefix("Version "))
        // The build number is deliberately not shown to users.
        #expect(AppInfo.version.contains("(") == false)
    }
}
