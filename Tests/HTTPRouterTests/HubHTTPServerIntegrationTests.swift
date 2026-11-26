import XCTest
@testable import DevAlias

final class HubHTTPServerIntegrationTests: XCTestCase {
    func testStartServesHealthDashboardAndPorts() async throws {
        let html = "<html>DevAlias stub</html>"
        let server = HubHTTPServer(dashboardHTML: html)
        let port: UInt16 = 49_287

        try server.start(port: port)
        defer { server.stop() }

        // Allow listener to become ready.
        try await Task.sleep(nanoseconds: 200_000_000)

        let health = try await get("http://127.0.0.1:\(port)/health")
        XCTAssertEqual(health.status, 200)
        XCTAssertEqual(health.body, "OK\n")

        let home = try await get("http://127.0.0.1:\(port)/")
        XCTAssertEqual(home.status, 200)
        XCTAssertTrue(home.body.contains("DevAlias"))

        server.updateServers([
            DiscoveredServer(
                port: 5173,
                processName: "node",
                projectName: "vite-app",
                stack: .vite,
                accessibility: .lanReachable
            )
        ])
        let ports = try await get("http://127.0.0.1:\(port)/api/ports")
        XCTAssertEqual(ports.status, 200)
        XCTAssertTrue(ports.body.contains("vite-app"))
        XCTAssertTrue(ports.headers["Content-Type"]?.contains("application/json") == true)
    }

    private struct HTTPResult {
        var status: Int
        var body: String
        var headers: [String: String]
    }

    private func get(_ urlString: String) async throws -> HTTPResult {
        let url = URL(string: urlString)!
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let k = key as? String, let v = value as? String {
                headers[k] = v
            }
        }
        return HTTPResult(
            status: http.statusCode,
            body: String(data: data, encoding: .utf8) ?? "",
            headers: headers
        )
    }
}
