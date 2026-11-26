import Foundation

/// v2 reverse-proxy path routing — stub only in v1.
/// See docs/phases/phase-10-post-1.0.md and DEVALIAS-FULL-PRODUCT §4.10.
protocol ProxyRouter: Sendable {
    // Intentionally empty in v1. Implementations land post-1.0.
}

/// Placeholder model so storage can grow to multi-route without reshaping v1 settings.
struct ProxyRoute: Codable, Equatable, Sendable {
    var pathPrefix: String
    var upstreamPort: Int
}
