import XCTest
@testable import DeveloperAssistant

@MainActor
final class ShortcutStoreTests: XCTestCase {
    func testDefaultShortcutsFollowCatalogOrder() {
        let defaults = makeDefaults()
        let store = ShortcutStore(defaults: defaults)

        XCTAssertEqual(store.pinnedModuleIDs, AppModuleCatalog.defaultPinnedIDs)
    }

    func testPinningChangesPersist() {
        let defaults = makeDefaults()
        let store = ShortcutStore(defaults: defaults)
        store.setPinned(.certificates, false)
        store.moveUp(.deployments)

        let restored = ShortcutStore(defaults: defaults)

        XCTAssertFalse(restored.isPinned(.certificates))
        XCTAssertEqual(restored.pinnedModuleIDs, [.dns, .deployments, .servers])
    }

    func testStoredDuplicatesAreSanitized() throws {
        let defaults = makeDefaults()
        let data = try JSONEncoder().encode([AppModuleID.dns, .dns, .servers])
        defaults.set(data, forKey: ShortcutStore.storageKey)

        let store = ShortcutStore(defaults: defaults)

        XCTAssertEqual(store.pinnedModuleIDs, [.dns, .servers])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ShortcutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
