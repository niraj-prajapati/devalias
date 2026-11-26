import XCTest
@testable import DevAlias

final class ModelCodableTests: XCTestCase {
    func testTechStackCoversExpectedCases() {
        let raw = TechStack.allCases.map(\.rawValue)
        XCTAssertEqual(
            Set(raw),
            Set(["node", "vite", "next", "python", "php", "ruby", "go", "docker", "unknown"])
        )
    }

    func testNetworkAccessibilityDistinguishesLocalhostVsLAN() {
        XCTAssertTrue(NetworkAccessibility.localhostOnly.showsBindWarning)
        XCTAssertFalse(NetworkAccessibility.lanReachable.showsBindWarning)
    }

    func testDiscoveredServerRoundTripsCodable() throws {
        let server = DiscoveredServer(
            port: 5173,
            pid: 4242,
            processName: "node",
            projectName: "my-app",
            stack: .vite,
            accessibility: .lanReachable,
            bindAddresses: ["0.0.0.0"]
        )
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(DiscoveredServer.self, from: data)
        XCTAssertEqual(decoded, server)
        XCTAssertEqual(decoded.id, "5173-4242")
    }

    func testHubStatusHubURLWhenRunning() {
        var status = HubStatus.idle(alias: "dev", highPort: 49200)
        XCTAssertNil(status.hubURL)
        status.runState = .running
        XCTAssertEqual(status.hubURL?.absoluteString, "http://dev.local:49200")
    }
}
