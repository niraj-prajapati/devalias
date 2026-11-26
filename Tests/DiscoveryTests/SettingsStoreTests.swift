import XCTest
@testable import DevAlias

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "DevAlias.SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultHighPortAndClamping() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.highPort, 49_200)

        store.highPort = 80
        XCTAssertEqual(store.highPort, 1024)

        store.highPort = 70_000
        XCTAssertEqual(store.highPort, 65_535)
    }

    func testAliasValidation() {
        XCTAssertTrue(SettingsStore.isValidAlias("dev"))
        XCTAssertTrue(SettingsStore.isValidAlias("my-mac"))
        XCTAssertFalse(SettingsStore.isValidAlias("-bad"))
        XCTAssertFalse(SettingsStore.isValidAlias("bad-"))
        XCTAssertFalse(SettingsStore.isValidAlias("has space"))
        XCTAssertFalse(SettingsStore.isValidAlias(""))
    }

    func testPersistenceAcrossInstances() {
        let first = SettingsStore(defaults: defaults)
        XCTAssertTrue(first.setHostnameAlias("studio"))
        first.highPort = 50_000
        first.autoStartServer = true
        first.ignoredPorts = [5000, 7000]

        let second = SettingsStore(defaults: defaults)
        XCTAssertEqual(second.hostnameAlias, "studio")
        XCTAssertEqual(second.highPort, 50_000)
        XCTAssertTrue(second.autoStartServer)
        XCTAssertEqual(second.ignoredPorts, [5000, 7000])
    }

    func testRejectsInvalidAliasWithoutMutating() {
        let store = SettingsStore(defaults: defaults)
        let before = store.hostnameAlias
        XCTAssertFalse(store.setHostnameAlias("not valid!"))
        XCTAssertEqual(store.hostnameAlias, before)
    }
}
