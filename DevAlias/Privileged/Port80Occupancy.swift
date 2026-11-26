import Foundation

/// Detects whether something is already listening on TCP port 80.
enum Port80Occupancy {
    struct Listener: Equatable {
        var processName: String
        var pid: String
    }

    static func currentListeners() -> [Listener] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:80", "-sTCP:LISTEN"]
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

        var results: [Listener] = []
        for line in text.split(separator: "\n").dropFirst() { // skip header
            let cols = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard cols.count >= 2 else { continue }
            results.append(Listener(processName: cols[0], pid: cols[1]))
        }
        return results
    }

    static func isBusy() -> Bool {
        !currentListeners().isEmpty
    }

    static func busyMessage() -> String? {
        let listeners = currentListeners()
        guard !listeners.isEmpty else { return nil }
        let summary = listeners.map { "\($0.processName) (pid \($0.pid))" }.joined(separator: ", ")
        return "Port 80 is already in use by \(summary). Stop that service before enabling DevAlias Port 80 forwarding."
    }
}
