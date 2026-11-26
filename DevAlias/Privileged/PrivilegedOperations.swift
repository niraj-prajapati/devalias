import Foundation

/// Thin client for Port 80 pfctl install/uninstall (MVP: admin scripts).
@MainActor
enum PrivilegedOperations {
    enum OperationError: Error, LocalizedError {
        case port80Busy(String)
        case scriptMissing
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .port80Busy(let message): return message
            case .scriptMissing: return "Install/uninstall scripts are missing from the app bundle."
            case .failed(let message): return message
            }
        }
    }

    struct Status: Equatable {
        var anchorFilePresent: Bool
        var pfConfSnippetPresent: Bool
        var installed: Bool { anchorFilePresent }
    }

    static func status() -> Status {
        let anchorPresent = FileManager.default.fileExists(atPath: PFAnchorRenderer.anchorPath)
        let pfConf = (try? String(contentsOfFile: "/etc/pf.conf", encoding: .utf8)) ?? ""
        let snippetPresent =
            pfConf.contains(PFAnchorRenderer.anchorName)
            || pfConf.contains(PFAnchorRenderer.pfConfMarkerBegin)
        return Status(anchorFilePresent: anchorPresent, pfConfSnippetPresent: snippetPresent)
    }

    /// Installs Port 80 → highPort redirect. Prompts for admin password.
    static func enablePort80Forwarding(highPort: Int, interface: String? = nil, redirectIPv4: String? = nil) throws {
        if let busy = Port80Occupancy.busyMessage() {
            throw OperationError.port80Busy(busy)
        }
        guard let script = AdminScriptRunner.bundledScriptURL(named: "install-pf-anchor") else {
            throw OperationError.scriptMissing
        }

        let address = LANAddressProvider.primaryAddress()
        let lanIP = redirectIPv4 ?? address?.ipv4
        guard let lanIP else {
            throw OperationError.failed("No LAN IPv4 — connect to Wi‑Fi before enabling Port 80.")
        }
        let iface = interface ?? address?.interface ?? "en0"

        let anchor = PFAnchorRenderer.anchorFileContents(
            highPort: highPort,
            interface: iface,
            redirectIPv4: lanIP
        )
        let tmpAnchor = FileManager.default.temporaryDirectory
            .appendingPathComponent("devalias-pf-anchor-\(UUID().uuidString).conf")
        try anchor.write(to: tmpAnchor, atomically: true, encoding: .utf8)

        let command = [
            "/bin/bash",
            shellQuote(script.path),
            "--high-port", "\(SettingsStore.clampHighPort(highPort))",
            "--interface", shellQuote(iface),
            "--redirect-to", shellQuote(lanIP),
            "--anchor-file", shellQuote(tmpAnchor.path),
        ].joined(separator: " ")

        do {
            _ = try AdminScriptRunner.runAdminShell(command)
        } catch {
            try? FileManager.default.removeItem(at: tmpAnchor)
            throw OperationError.failed(error.localizedDescription)
        }
        try? FileManager.default.removeItem(at: tmpAnchor)
    }

    static func disablePort80Forwarding() throws {
        guard let script = AdminScriptRunner.bundledScriptURL(named: "uninstall-pf-anchor") else {
            throw OperationError.scriptMissing
        }
        let command = "/bin/bash \(shellQuote(script.path))"
        do {
            _ = try AdminScriptRunner.runAdminShell(command)
        } catch {
            throw OperationError.failed(error.localizedDescription)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
