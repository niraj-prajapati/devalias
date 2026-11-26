import XCTest
@testable import DevAlias

final class PFAnchorRendererTests: XCTestCase {
    func testAnchorRedirectsLANAndLoopbackHairpin() {
        let text = PFAnchorRenderer.anchorFileContents(
            highPort: 49200,
            interface: "all",
            redirectIPv4: "192.168.1.10"
        )
        // Phones: LAN iface → LAN IP
        XCTAssertTrue(text.contains("on en0 inet proto tcp from any to any port 80 -> 192.168.1.10 port 49200"))
        // Mac browser hairpin: lo0 → 127.0.0.1
        XCTAssertTrue(text.contains("on lo0 inet proto tcp from any to any port 80 -> 127.0.0.1 port 49200"))
        XCTAssertTrue(text.hasSuffix("\n"), "pfctl requires trailing newline")
    }

    func testAnchorSpecificInterface() {
        let text = PFAnchorRenderer.anchorFileContents(
            highPort: 50000,
            interface: "en0",
            redirectIPv4: "10.0.0.5"
        )
        XCTAssertTrue(text.contains("rdr pass on en0 inet proto tcp"))
        XCTAssertTrue(text.contains("-> 10.0.0.5 port 50000"))
        XCTAssertTrue(text.contains("rdr pass on lo0 inet proto tcp"))
    }

    func testPfConfSnippetHasAnchorLines() {
        let snippet = PFAnchorRenderer.pfConfIncludeSnippet()
        XCTAssertTrue(snippet.contains("rdr-anchor \"com.nandroidex.devalias\""))
        XCTAssertTrue(snippet.contains(PFAnchorRenderer.anchorPath))
        XCTAssertEqual(PFAnchorRenderer.pfConfRdrAnchorLine(), "rdr-anchor \"com.nandroidex.devalias\"")
    }

    func testClampsHighPort() {
        let text = PFAnchorRenderer.anchorFileContents(
            highPort: 80,
            interface: nil,
            redirectIPv4: "192.168.0.2"
        )
        XCTAssertTrue(text.contains("port 1024"))
    }
}
