import XCTest
@testable import DevAlias

final class HTTPRouterTests: XCTestCase {
    func testHealthRoute() {
        let router = HTTPRouter(servers: [], dashboardHTML: "<html>DevAlias</html>")
        let response = router.handle(HTTPRequest(method: "GET", path: "/health", headers: [:]))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: response.body, encoding: .utf8), "OK\n")
    }

    func testDashboardRoute() {
        let router = HTTPRouter(servers: [], dashboardHTML: "<html>DevAlias</html>")
        let response = router.handle(HTTPRequest(method: "GET", path: "/", headers: [:]))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "text/html; charset=utf-8")
        XCTAssertTrue(String(data: response.body, encoding: .utf8)?.contains("DevAlias") == true)
    }

    func testPortsJSON() throws {
        let server = DiscoveredServer(
            port: 3000,
            pid: 1,
            processName: "node",
            projectName: "demo",
            stack: .node,
            accessibility: .lanReachable
        )
        let router = HTTPRouter(servers: [server], dashboardHTML: "")
        let response = router.handle(HTTPRequest(method: "GET", path: "/api/ports", headers: [:]))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "application/json; charset=utf-8")
        let decoded = try JSONDecoder().decode([DiscoveredServer].self, from: response.body)
        XCTAssertEqual(decoded, [server])
    }

    func testRequestParser() {
        let raw = Data("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8)
        let req = HTTPRequestParser.parse(raw)
        XCTAssertEqual(req?.method, "GET")
        XCTAssertEqual(req?.path, "/health")
        XCTAssertEqual(req?.headers["host"], "localhost")
    }
}
