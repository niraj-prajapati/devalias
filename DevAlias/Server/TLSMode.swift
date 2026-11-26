import Foundation

/// Local HTTPS (mkcert) mode — v1 ships `.off` only.
/// Certificate store / mkcert integration is post-1.0 (phase-10).
enum TLSMode: String, Codable, Sendable, Equatable {
    /// Plain HTTP on the hub high port (v1).
    case off
    // Future: case mkcert, case customCertificate
}

/// Hook for a future certificate provider. No behavior in v1.
protocol CertificateStore: Sendable {
    // Intentionally empty in v1.
}
