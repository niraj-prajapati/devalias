import XCTest
@testable import DevAlias

final class DiscoveryEngineTests: XCTestCase {
    func testParseLsofMachineOutput() {
        let sample = """
        p1234
        cnode
        PTCP
        n*:5173
        p5678
        cpython3
        PTCP
        n127.0.0.1:8000
        """
        let sockets = PortScanner.parseLsofMachineOutput(sample)
        XCTAssertEqual(sockets.count, 2)
        XCTAssertEqual(sockets[0].port, 5173)
        XCTAssertEqual(sockets[0].processName, "node")
        XCTAssertEqual(sockets[0].bindAddresses, ["*"])
        XCTAssertEqual(sockets[1].port, 8000)
        XCTAssertEqual(sockets[1].bindAddresses, ["127.0.0.1"])
    }

    func testSystemFilterHidesRapportAndAirPlay() {
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "rapportd", port: 49152))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "ControlCenter", port: 5000))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "node", port: 3000, ignoredPorts: [3000]))
        XCTAssertFalse(SystemProcessFilter.shouldHide(processName: "node", port: 5173))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "adb", port: 5037))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "jetbrains-toolbox", port: 56644))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "claude", port: 53561))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "2.1.330", port: 60137))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "Cursor", port: 5500))
        XCTAssertTrue(SystemProcessFilter.shouldHide(processName: "dart", port: 9101))
        XCTAssertTrue(SystemProcessFilter.isLikelyDevServer(processName: "node", projectName: "app", stack: .vite))
        XCTAssertTrue(SystemProcessFilter.isLikelyDevServer(processName: "dart", projectName: "app", stack: .unknown))
        XCTAssertFalse(SystemProcessFilter.isLikelyDevServer(processName: "SomeDaemon", projectName: "SomeDaemon", stack: .unknown))
        // Cwd/project name alone must not keep IDE helpers
        XCTAssertFalse(SystemProcessFilter.isLikelyDevServer(processName: "claude", projectName: "playable-studio", stack: .unknown))
    }

    func testStackHeuristicsFixtures() {
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "node", cwd: "/app", filenames: ["vite.config.ts", "package.json"])),
            .vite
        )
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "node", cwd: "/app", filenames: ["next.config.mjs", "package.json"])),
            .next
        )
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "python3", cwd: "/api", filenames: ["pyproject.toml"])),
            .python
        )
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "php", cwd: "/web", filenames: ["index.php"])),
            .php
        )
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "myapi", cwd: "/srv", filenames: ["go.mod"])),
            .go
        )
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "com.docker.backend", cwd: "/", filenames: [])),
            .docker
        )
        XCTAssertEqual(
            StackHeuristics.infer(.init(processName: "node", cwd: "/app", filenames: ["package.json"])),
            .node
        )
    }

    func testAccessibilityLocalhostVsLAN() {
        XCTAssertEqual(DiscoveryEngine.accessibility(for: ["127.0.0.1"]), .localhostOnly)
        XCTAssertEqual(DiscoveryEngine.accessibility(for: ["::1"]), .localhostOnly)
        XCTAssertEqual(DiscoveryEngine.accessibility(for: ["0.0.0.0"]), .lanReachable)
        XCTAssertEqual(DiscoveryEngine.accessibility(for: ["*"]), .lanReachable)
        XCTAssertEqual(DiscoveryEngine.accessibility(for: ["192.168.1.10"]), .lanReachable)
    }

    func testLiveScanCompletesQuickly() {
        let start = Date()
        let sockets = PortScanner.scanTCPListeners()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 2.5, "Scan should finish within ~2s")
        // Soft assert: something is usually listening on a developer Mac.
        _ = sockets
    }

    func testLiveDiscoverOmitsToolingNoise() {
        let found = DiscoveryEngine.discover(ignoredPorts: [49200])
        let names = found.map { SystemProcessFilter.basename($0.processName) }
        for noise in ["adb", "claude", "jetbrains-toolbox", "cursor", "rapportd", "controlce"] {
            XCTAssertFalse(names.contains(noise), "Should hide \(noise), got \(names)")
        }
        XCTAssertFalse(names.contains(where: { SystemProcessFilter.isVersionedAgentName($0) }))
        for server in found {
            XCTAssertFalse(SystemProcessFilter.shouldHide(processName: server.processName, port: server.port, pid: server.pid))
            XCTAssertTrue(
                SystemProcessFilter.isLikelyDevServer(
                    processName: server.processName,
                    projectName: server.projectName,
                    stack: server.stack
                )
            )
        }
    }
}
