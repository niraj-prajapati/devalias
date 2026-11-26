import Foundation

/// Raw TCP listen-table row before enrichment.
struct ListenSocket: Equatable, Sendable {
    var port: Int
    var bindAddresses: [String]
    var pid: Int32?
    var processName: String
}

/// Snapshot of listening TCP ports.
/// v1 uses `lsof` (reliable, no third-party deps). libproc enrichment can replace later.
enum PortScanner {
    /// Off-main-thread safe.
    static func scanTCPListeners() -> [ListenSocket] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // -nP numeric, -iTCP listen only, -F machine-readable fields
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcPn"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return []
        }
        return parseLsofMachineOutput(text)
    }

    /// Parses `lsof -FpcPn` output into listen sockets (merged by port+pid).
    static func parseLsofMachineOutput(_ text: String) -> [ListenSocket] {
        var currentPID: Int32?
        var currentName = ""
        var currentPort: Int?
        var currentAddrs: [String] = []
        var results: [ListenSocket] = []

        func flush() {
            guard let port = currentPort, port > 0 else {
                currentPort = nil
                currentAddrs = []
                return
            }
            let name = currentName.isEmpty ? "unknown" : currentName
            if let idx = results.firstIndex(where: { $0.port == port && $0.pid == currentPID }) {
                var existing = results[idx]
                for addr in currentAddrs where !existing.bindAddresses.contains(addr) {
                    existing.bindAddresses.append(addr)
                }
                results[idx] = existing
            } else {
                results.append(
                    ListenSocket(
                        port: port,
                        bindAddresses: currentAddrs,
                        pid: currentPID,
                        processName: name
                    )
                )
            }
            currentPort = nil
            currentAddrs = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            guard let first = line.first else { continue }
            let value = String(line.dropFirst())
            switch first {
            case "p":
                flush()
                currentPID = Int32(value)
            case "c":
                currentName = value
            case "P":
                // protocol — ignore (TCP implied)
                break
            case "n":
                // name like *:5173, 127.0.0.1:8000, [::1]:8080, 192.168.1.2:3000
                if let parsed = parseEndpoint(value) {
                    if currentPort != parsed.port {
                        flush()
                        currentPort = parsed.port
                    }
                    currentAddrs.append(parsed.address)
                }
            default:
                break
            }
        }
        flush()
        return results.sorted { $0.port < $1.port }
    }

    private static func parseEndpoint(_ name: String) -> (address: String, port: Int)? {
        // IPv6 in brackets: [fe80::1]:8080 or [::1]:8080
        if name.hasPrefix("[") {
            guard let close = name.firstIndex(of: "]") else { return nil }
            let addr = String(name[name.index(after: name.startIndex)..<close])
            let rest = name[name.index(after: close)...]
            guard rest.hasPrefix(":"), let port = Int(rest.dropFirst()) else { return nil }
            return (addr, port)
        }
        // IPv4 or *:port
        guard let colon = name.lastIndex(of: ":") else { return nil }
        let addr = String(name[..<colon])
        guard let port = Int(name[name.index(after: colon)...]) else { return nil }
        return (addr.isEmpty ? "*" : addr, port)
    }
}
