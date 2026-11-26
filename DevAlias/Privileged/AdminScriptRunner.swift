import Foundation

/// Runs reviewed shell scripts with an admin password prompt (MVP path).
enum AdminScriptRunner {
    enum RunnerError: Error, LocalizedError {
        case scriptMissing(String)
        case cancelledOrFailed(String)

        var errorDescription: String? {
            switch self {
            case .scriptMissing(let path): return "Script not found: \(path)"
            case .cancelledOrFailed(let message): return message
            }
        }
    }

    @discardableResult
    static func runAdminShell(_ command: String) throws -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw RunnerError.cancelledOrFailed(error.localizedDescription)
        }
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let combined = [stderr, stdout].filter { !$0.isEmpty }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            throw RunnerError.cancelledOrFailed(combined.isEmpty ? "Admin authorization failed or was cancelled." : combined)
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func bundledScriptURL(named name: String) -> URL? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: "sh"),
            Bundle.main.url(forResource: name, withExtension: "sh", subdirectory: "Scripts"),
            Bundle.main.resourceURL?.appendingPathComponent("Scripts/\(name).sh"),
            // Dev / Xcode: repo Scripts next to project
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent() // Privileged
                .deletingLastPathComponent() // DevAlias
                .deletingLastPathComponent() // repo
                .appendingPathComponent("Scripts/\(name).sh"),
        ]
        for case let url? in candidates where FileManager.default.isReadableFile(atPath: url.path) {
            return url
        }
        return nil
    }
}
