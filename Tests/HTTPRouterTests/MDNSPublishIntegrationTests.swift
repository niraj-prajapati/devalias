import XCTest
@testable import DevAlias

final class MDNSPublishIntegrationTests: XCTestCase {
    func testPublishMakesAliasResolvable() async throws {
        // GitHub-hosted macOS VMs block multicast / .local resolution.
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw XCTSkip("mDNS resolve not available on CI runners")
        }
        guard let ip = LANAddressProvider.primaryIPv4() else {
            throw XCTSkip("No LAN IPv4 available for mDNS test")
        }

        let alias = "devaliastest\(Int.random(in: 1000 ... 9999))"
        let mdns = MDNSAliasService()
        try mdns.publish(alias: alias, ipv4: ip, port: 49_200)
        defer { mdns.unpublish() }

        // Allow mDNS probe / cache settle.
        try await Task.sleep(nanoseconds: 2_500_000_000)

        let resolved = await resolveIPv4("\(alias).local")
        XCTAssertNotNil(resolved, "Expected \(alias).local to resolve after RegisterRecord")
        XCTAssertEqual(resolved, ip)
    }

    private func resolveIPv4(_ host: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_INET,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: 0,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var result: UnsafeMutablePointer<addrinfo>?
                let code = getaddrinfo(host, nil, &hints, &result)
                defer { if let result { freeaddrinfo(result) } }
                guard code == 0, let result, let addr = result.pointee.ai_addr else {
                    continuation.resume(returning: nil)
                    return
                }
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let gni = getnameinfo(
                    addr,
                    socklen_t(result.pointee.ai_addrlen),
                    &buffer,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                continuation.resume(returning: gni == 0 ? String(cString: buffer) : nil)
            }
        }
    }
}
