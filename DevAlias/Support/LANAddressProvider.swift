import Foundation

/// Best-effort primary private IPv4 for hub URLs and mDNS.
enum LANAddressProvider {
    enum ProviderError: Error, Equatable {
        case noIPv4Address
    }

    struct Address: Equatable {
        var interface: String
        var ipv4: String
    }

    /// Returns the preferred private LAN IPv4, or nil if offline / no usable interface.
    static func primaryIPv4() -> String? {
        primaryAddress()?.ipv4
    }

    /// Preferred Wi‑Fi/Ethernet IPv4 + interface name (e.g. `en0`).
    static func primaryAddress() -> Address? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }

        var candidates: [(name: String, ip: String, score: Int)] = []

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard isUp, !isLoopback else { continue }

            guard let sa = current.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                sa,
                socklen_t(MemoryLayout<sockaddr_in>.size),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }

            let ip = String(cString: hostname)
            let name = String(cString: current.pointee.ifa_name)
            guard let score = score(interface: name, ip: ip) else { continue }
            candidates.append((name, ip, score))
        }

        guard let best = candidates.max(by: { $0.score < $1.score }) else { return nil }
        return Address(interface: best.name, ipv4: best.ip)
    }

    static func primaryIPv4OrThrow() throws -> String {
        guard let ip = primaryIPv4() else { throw ProviderError.noIPv4Address }
        return ip
    }

    /// Higher score = preferred. Returns nil for non-private / unusable addresses.
    private static func score(interface name: String, ip: String) -> Int? {
        guard isPrivateIPv4(ip) else { return nil }
        var score = 10
        if name.hasPrefix("en") { score += 50 } // Ethernet / Wi‑Fi
        if name.hasPrefix("bridge") { score += 20 }
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") {
            score -= 40 // VPN — usually not the LAN phones share
        }
        if ip.hasPrefix("10.") || ip.hasPrefix("192.168.") { score += 5 }
        if ip.hasPrefix("172.") { score += 3 }
        return score
    }

    static func isPrivateIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        let a = parts[0], b = parts[1]
        if a == 10 { return true }
        if a == 192 && b == 168 { return true }
        if a == 172 && (16 ... 31).contains(b) { return true }
        return false
    }
}
