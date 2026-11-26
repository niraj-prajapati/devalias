import XCTest
@testable import DevAlias

final class LANAddressProviderTests: XCTestCase {
    func testPrivateIPv4Detection() {
        XCTAssertTrue(LANAddressProvider.isPrivateIPv4("192.168.1.10"))
        XCTAssertTrue(LANAddressProvider.isPrivateIPv4("10.0.0.5"))
        XCTAssertTrue(LANAddressProvider.isPrivateIPv4("172.16.0.1"))
        XCTAssertTrue(LANAddressProvider.isPrivateIPv4("172.31.255.255"))
        XCTAssertFalse(LANAddressProvider.isPrivateIPv4("172.15.0.1"))
        XCTAssertFalse(LANAddressProvider.isPrivateIPv4("8.8.8.8"))
        XCTAssertFalse(LANAddressProvider.isPrivateIPv4("127.0.0.1"))
        XCTAssertFalse(LANAddressProvider.isPrivateIPv4("not-an-ip"))
    }

    func testPrimaryIPv4IsNilOrPrivate() {
        if let ip = LANAddressProvider.primaryIPv4() {
            XCTAssertTrue(LANAddressProvider.isPrivateIPv4(ip), "Expected private IPv4, got \(ip)")
        }
        // nil is acceptable when offline / no LAN — no hard failure.
    }
}
