import Foundation

/// Pure generator for DevAlias pf anchor text (no execution).
enum PFAnchorRenderer {
    static let anchorName = "com.nandroidex.devalias"
    static let anchorPath = "/etc/pf.anchors/com.nandroidex.devalias"
    static let pfConfMarkerBegin = "# BEGIN com.nandroidex.devalias"
    static let pfConfMarkerEnd = "# END com.nandroidex.devalias"

    /// - Parameters:
    ///   - highPort: Hub listen port (e.g. 49200).
    ///   - interface: Wi‑Fi/Ethernet iface (`en0`) for phone/LAN traffic.
    ///   - redirectIPv4: **Must be the Mac LAN IP**, not 127.0.0.1 — pf rdr to loopback
    ///     often black-holes packets from other devices on macOS.
    ///
    /// Emits two redirects:
    /// 1. `on <iface>` → LAN IP (phones hitting Port 80)
    /// 2. `on lo0` → 127.0.0.1 (Mac browser → mac.local / own LAN IP uses loopback and
    ///    would otherwise bypass the en0 rule)
    static func anchorFileContents(
        highPort: Int,
        interface: String? = nil,
        redirectIPv4: String
    ) -> String {
        let port = SettingsStore.clampHighPort(highPort)
        let iface = (interface?.isEmpty == false && interface?.lowercased() != "all")
            ? interface!
            : "en0"
        // ASCII only; always end with a newline — pfctl syntax-errors a final line without one.
        return """
        # DevAlias Port 80 -> \(redirectIPv4):\(port) (LAN) + lo0 -> 127.0.0.1:\(port) (Mac)
        rdr pass on \(iface) inet proto tcp from any to any port 80 -> \(redirectIPv4) port \(port)
        rdr pass on lo0 inet proto tcp from any to any port 80 -> 127.0.0.1 port \(port)

        """
    }

    static func pfConfRdrAnchorLine() -> String {
        "rdr-anchor \"\(anchorName)\""
    }

    static func pfConfLoadAnchorLine() -> String {
        "load anchor \"\(anchorName)\" from \"\(anchorPath)\""
    }

    static func pfConfIncludeSnippet() -> String {
        """
        \(pfConfRdrAnchorLine())
        \(pfConfLoadAnchorLine())
        """
    }
}
