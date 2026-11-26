import Foundation

/// Actionable copy for common failure modes (Phase 8).
enum UserFacingErrors {
    static let portInUse =
        "That hub port is already in use. Pick another high port in Settings (1024–65535), then Start Hub again."

    static let firewallBlock =
        "macOS Firewall may be blocking inbound connections. System Settings → Network → Firewall → Options → allow DevAlias (or briefly turn Firewall off to test)."

    static let noLANIP =
        "No LAN IPv4 address. Join Wi‑Fi / Ethernet on the same network as your phone. Guest Wi‑Fi with AP isolation often blocks phone → Mac."

    static let pfDisabled =
        "Packet filter (pf) could not load the Port 80 redirect. Re-enable Port 80 in Settings (admin password). If it keeps failing, check `/etc/pf.conf` wasn’t customized incorrectly."

    static let port80Busy =
        "Port 80 is already taken (AirPlay Receiver, another web server, or a leftover listener). Turn off AirPlay Receiver in System Settings → General → AirDrop & Handoff, or stop the other process, then Enable Port 80 again."

    static let mdnsResolveFail =
        "mDNS/.local didn’t resolve on this device. Use the LAN IP URL from the menu (QR prefers it). Android often can’t resolve *.local."

    static let apIsolation =
        "Phone and Mac can’t see each other (AP / client isolation). Use the main LAN SSID, not guest Wi‑Fi, or open the LAN IP while both are on the same network."

    static func mapBindFailure(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("address already in use") || lower.contains("eaddrinuse") || lower.contains("already in use") {
            return portInUse
        }
        return message
    }

    static func mapPrivilegedFailure(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("port 80") && (lower.contains("in use") || lower.contains("already")) {
            return port80Busy
        }
        if lower.contains("pfctl") || lower.contains("pf.conf") || lower.contains("anchor") {
            return pfDisabled + "\n\n" + message
        }
        return message
    }
}
