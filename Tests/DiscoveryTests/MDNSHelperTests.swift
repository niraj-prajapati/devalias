import XCTest
@testable import DevAlias

final class MDNSHelperTests: XCTestCase {
    func testStripLocalSuffix() {
        XCTAssertEqual(SettingsStore.stripLocalSuffix("dev.local"), "dev")
        XCTAssertEqual(SettingsStore.stripLocalSuffix("Dev.LOCAL"), "Dev")
        XCTAssertEqual(SettingsStore.stripLocalSuffix("studio"), "studio")
        XCTAssertEqual(SettingsStore.stripLocalSuffix("  my-mac.local  "), "my-mac")
    }

    func testRejectsAliasWithSpaces() {
        XCTAssertFalse(SettingsStore.isValidAlias("bad name"))
        XCTAssertFalse(SettingsStore.isValidAlias("bad.local name"))
        XCTAssertTrue(SettingsStore.isValidAlias("dev.local")) // stripped then validated
        XCTAssertTrue(SettingsStore.isValidAlias("dev"))
    }

    func testCurrentLocalHostNameReadable() {
        let name = HostNameHelper.currentLocalHostName()
        // May be nil in weird CI, but on a developer Mac should exist.
        if let name {
            XCTAssertFalse(name.isEmpty)
        }
    }
}
