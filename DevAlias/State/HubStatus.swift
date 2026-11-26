import Foundation

/// Lifecycle of the embedded hub HTTP server (no networking in this type).
enum HubRunState: String, Codable, Sendable, Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error
}

/// Snapshot of hub reachability for Menu Bar + future `/health` consumers.
struct HubStatus: Codable, Equatable, Sendable {
    var runState: HubRunState
    var highPort: Int
    /// Hostname alias without `.local` suffix.
    var alias: String
    var lanIP: String?
    var lastError: String?

    var hubURL: URL? {
        guard runState == .running else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = "\(alias).local"
        if highPort != 80 {
            components.port = highPort
        }
        return components.url
    }

    static func idle(alias: String, highPort: Int) -> HubStatus {
        HubStatus(
            runState: .stopped,
            highPort: highPort,
            alias: alias,
            lanIP: nil,
            lastError: nil
        )
    }
}
