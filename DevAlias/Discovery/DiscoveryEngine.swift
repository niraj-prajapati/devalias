import Foundation

/// Orchestrates scan → filter → enrich → keep likely dev servers.
enum DiscoveryEngine {
    static func accessibility(for bindAddresses: [String]) -> NetworkAccessibility {
        let normalized = bindAddresses.map { $0.lowercased() }
        if normalized.isEmpty { return .localhostOnly }

        let localhostOnlyMarkers: Set<String> = ["127.0.0.1", "::1", "localhost"]
        let lanMarkers = normalized.contains { addr in
            addr == "*" || addr == "0.0.0.0" || addr == "::"
                || (!localhostOnlyMarkers.contains(addr) && !addr.hasPrefix("127.") && addr != "::1")
        }
        if lanMarkers { return .lanReachable }

        let allLocal = normalized.allSatisfy { localhostOnlyMarkers.contains($0) || $0.hasPrefix("127.") }
        return allLocal ? .localhostOnly : .lanReachable
    }

    static func discover(
        ignoredPorts: [Int],
        ignoredProcessSubstrings: [String] = []
    ) -> [DiscoveredServer] {
        let raw = PortScanner.scanTCPListeners()
        let filtered = SystemProcessFilter.filter(
            raw,
            ignoredPorts: ignoredPorts,
            ignoredProcessSubstrings: ignoredProcessSubstrings
        )

        let enriched: [DiscoveredServer] = filtered.map { socket in
            let project = ProcessInspector.projectName(pid: socket.pid, processName: socket.processName)
            let stack = StackHeuristics.infer(processName: socket.processName, pid: socket.pid)
            let access = accessibility(for: socket.bindAddresses)
            return DiscoveredServer(
                port: socket.port,
                pid: socket.pid,
                processName: socket.processName,
                projectName: project,
                stack: stack,
                accessibility: access,
                bindAddresses: socket.bindAddresses
            )
        }

        return enriched.filter { server in
            guard SystemProcessFilter.isLikelyDevServer(
                processName: server.processName,
                projectName: server.projectName,
                stack: server.stack
            ) else {
                return false
            }
            // Dart/Flutter VM isolates & tooling bind localhost on random ports —
            // only keep them when they are actually LAN-reachable app servers.
            let base = SystemProcessFilter.basename(server.processName)
            if (base == "dart" || base.hasPrefix("dart") || base == "flutter"),
               server.accessibility == .localhostOnly
            {
                return false
            }
            return true
        }
    }
}
