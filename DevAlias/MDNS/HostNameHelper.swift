import Foundation

/// Read/write system `LocalHostName` via `scutil` (permanent opt-in path only).
enum HostNameHelper {
    enum HostError: Error, LocalizedError, Equatable {
        case emptyValue
        case invalidAlias
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyValue: return "LocalHostName was empty"
            case .invalidAlias: return "Invalid Bonjour hostname"
            case .commandFailed(let message): return message
            }
        }
    }

    static func currentLocalHostName() -> String? {
        let value = runScutil(["--get", "LocalHostName"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Sets system LocalHostName. May prompt for admin via osascript.
    static func setLocalHostName(_ alias: String, preferPrivileged: Bool = true) throws {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SettingsStore.isValidAlias(trimmed) else { throw HostError.invalidAlias }

        if !preferPrivileged {
            let output = runScutil(["--set", "LocalHostName", trimmed], captureStderr: true)
            if currentLocalHostName() == trimmed { return }
            throw HostError.commandFailed(output ?? "scutil --set failed")
        }

        try runAdminShell("scutil --set LocalHostName \(shellEscape(trimmed))")
        guard currentLocalHostName() == trimmed else {
            throw HostError.commandFailed("LocalHostName did not change after admin set")
        }
    }

    static func restoreLocalHostName(_ previous: String) throws {
        try setLocalHostName(previous, preferPrivileged: true)
    }

    private static func runScutil(_ arguments: [String], captureStderr: Bool = false) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = captureStderr ? pipe : Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func runAdminShell(_ command: String) throws {
        let script = "do shell script \"\(command)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw HostError.commandFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw HostError.commandFailed(err.isEmpty ? "Admin scutil failed" : err)
        }
    }

    private static func shellEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
