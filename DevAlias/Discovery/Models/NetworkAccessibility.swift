import Foundation

/// Whether a listener can be reached from another device on the LAN.
enum NetworkAccessibility: String, Codable, Sendable, Equatable {
    /// Bound only to loopback (`127.0.0.1` / `::1`) — phones cannot connect.
    case localhostOnly
    /// Bound to wildcard or a LAN interface — reachable if firewall allows.
    case lanReachable

    var showsBindWarning: Bool {
        self == .localhostOnly
    }
}
