import Foundation

/// A TCP listener discovered on the Mac, enriched for Menu Bar + `/api/ports`.
struct DiscoveredServer: Identifiable, Codable, Equatable, Sendable {
    /// Stable id for UI/diffing: `"\(port)-\(pid ?? 0)"`.
    var id: String
    var port: Int
    var pid: Int32?
    var processName: String
    var projectName: String
    var stack: TechStack
    var accessibility: NetworkAccessibility
    /// Raw bind addresses from the listen table (e.g. `127.0.0.1`, `*`, `0.0.0.0`).
    var bindAddresses: [String]

    init(
        port: Int,
        pid: Int32? = nil,
        processName: String,
        projectName: String,
        stack: TechStack = .unknown,
        accessibility: NetworkAccessibility,
        bindAddresses: [String] = []
    ) {
        self.id = "\(port)-\(pid ?? 0)"
        self.port = port
        self.pid = pid
        self.processName = processName
        self.projectName = projectName
        self.stack = stack
        self.accessibility = accessibility
        self.bindAddresses = bindAddresses
    }
}
