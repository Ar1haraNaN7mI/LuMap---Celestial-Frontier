import Foundation
import XCTest
@testable import Lumap

extension XCTestCase {
    /// Every fixture gets its own preferences domain. The default reader returns
    /// nil rather than contacting Keychain, even when the fixture uses loopback.
    /// Real model tests must explicitly opt in after checking their live-test flag.
    @MainActor
    func isolatedLumapStore(useSavedProvider: Bool = false) throws -> LumapStore {
        let suiteName = "com.local.lumap.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        if useSavedProvider {
            for key in ["lumap.provider.endpoint", "lumap.provider.model", "lumap.provider.style"] {
                if let value = UserDefaults.standard.object(forKey: key) { defaults.set(value, forKey: key) }
            }
            return LumapStore(defaults: defaults, credentialReader: {
                LumapKeychainStore.read(account: "active-provider")
            })
        }
        return LumapStore(defaults: defaults, credentialReader: { nil })
    }
}
