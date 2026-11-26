import Combine
import Foundation

/// Which URL the menu QR / copy affordance encodes.
enum ShareURLMode: String, CaseIterable, Sendable {
    /// `http://alias.local` — nicer when mDNS works.
    case aliasLocal = "aliasLocal"
    /// `http://LAN_IP/` — most reliable on phones.
    case lanIP = "lanIP"
}

/// Persistent user preferences (UserDefaults). No networking.
@MainActor
final class SettingsStore: ObservableObject {
    nonisolated static let defaultHighPort = 49_200
    nonisolated static let unprivilegedPortRange = 1024 ... 65_535

    private let defaults: UserDefaults
    private let keys = Keys()

    @Published var hostnameAlias: String {
        didSet { defaults.set(hostnameAlias, forKey: keys.hostnameAlias) }
    }

    @Published var highPort: Int {
        didSet {
            let clamped = Self.clampHighPort(highPort)
            if clamped != highPort {
                highPort = clamped
                return
            }
            defaults.set(clamped, forKey: keys.highPort)
        }
    }

    /// Whether the pfctl Port-80 forward anchor is currently installed.
    @Published var port80Installed: Bool {
        didSet { defaults.set(port80Installed, forKey: keys.port80Installed) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: keys.launchAtLogin) }
    }

    /// Auto-start the hub HTTP server when the app launches (default off).
    @Published var autoStartServer: Bool {
        didSet { defaults.set(autoStartServer, forKey: keys.autoStartServer) }
    }

    @Published var ignoredPorts: [Int] {
        didSet { defaults.set(ignoredPorts, forKey: keys.ignoredPorts) }
    }

    /// Case-insensitive substrings matched against process names during discovery.
    @Published var ignoredProcessSubstrings: [String] {
        didSet { defaults.set(ignoredProcessSubstrings, forKey: keys.ignoredProcessSubstrings) }
    }

    /// Previous system LocalHostName before an explicit permanent set (for Restore).
    @Published var previousLocalHostName: String? {
        didSet { defaults.set(previousLocalHostName, forKey: keys.previousLocalHostName) }
    }

    /// QR / share URL mode — default `.local` first; switch to LAN if phones fail.
    @Published var shareURLMode: ShareURLMode {
        didSet { defaults.set(shareURLMode.rawValue, forKey: keys.shareURLMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.string(forKey: Keys().hostnameAlias), !stored.isEmpty {
            self.hostnameAlias = Self.stripLocalSuffix(stored)
        } else {
            let initial = Self.defaultAliasFromSystem()
            self.hostnameAlias = initial
            defaults.set(initial, forKey: Keys().hostnameAlias)
        }

        let storedPort = defaults.object(forKey: Keys().highPort) as? Int
        self.highPort = Self.clampHighPort(storedPort ?? Self.defaultHighPort)

        self.port80Installed = defaults.bool(forKey: Keys().port80Installed)
        self.launchAtLogin = defaults.bool(forKey: Keys().launchAtLogin)
        self.autoStartServer = defaults.bool(forKey: Keys().autoStartServer)
        self.ignoredPorts = defaults.array(forKey: Keys().ignoredPorts) as? [Int] ?? []
        self.ignoredProcessSubstrings = defaults.stringArray(forKey: Keys().ignoredProcessSubstrings) ?? []
        self.previousLocalHostName = defaults.string(forKey: Keys().previousLocalHostName)
        if let raw = defaults.string(forKey: Keys().shareURLMode),
           let mode = ShareURLMode(rawValue: raw)
        {
            self.shareURLMode = mode
        } else {
            self.shareURLMode = .aliasLocal
        }
    }

    func setIgnoredPorts(fromCSV raw: String) {
        let parts = raw.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" || $0 == ";" })
        ignoredPorts = parts.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1 ... 65_535).contains($0) }
            .sorted()
    }

    func setIgnoredProcessSubstrings(fromCSV raw: String) {
        ignoredProcessSubstrings = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var ignoredPortsCSV: String {
        ignoredPorts.map(String.init).joined(separator: ", ")
    }

    var ignoredProcessSubstringsCSV: String {
        ignoredProcessSubstrings.joined(separator: ", ")
    }

    /// Bonjour-safe: letters, digits, hyphens; must start/end alphanumeric; max 63.
    nonisolated static func isValidAlias(_ raw: String) -> Bool {
        let alias = stripLocalSuffix(raw)
        guard !alias.isEmpty, alias.count <= 63 else { return false }
        guard alias.range(of: "^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$", options: .regularExpression) != nil else {
            return false
        }
        return true
    }

    nonisolated static func stripLocalSuffix(_ raw: String) -> String {
        var alias = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if alias.lowercased().hasSuffix(".local") {
            alias = String(alias.dropLast(6))
        }
        if alias.hasSuffix(".") {
            alias = String(alias.dropLast())
        }
        return alias
    }

    @discardableResult
    func setHostnameAlias(_ raw: String) -> Bool {
        let trimmed = Self.stripLocalSuffix(raw)
        guard Self.isValidAlias(trimmed) else { return false }
        hostnameAlias = trimmed
        return true
    }

    nonisolated static func clampHighPort(_ port: Int) -> Int {
        min(max(port, unprivilegedPortRange.lowerBound), unprivilegedPortRange.upperBound)
    }

    nonisolated static func defaultAliasFromSystem() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = ["--get", "LocalHostName"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if isValidAlias(value) { return value }
        } catch {
            // Fall through to default.
        }
        return "dev"
    }

    private struct Keys {
        let hostnameAlias = "settings.hostnameAlias"
        let highPort = "settings.highPort"
        let port80Installed = "settings.port80Installed"
        let launchAtLogin = "settings.launchAtLogin"
        let autoStartServer = "settings.autoStartServer"
        let ignoredPorts = "settings.ignoredPorts"
        let ignoredProcessSubstrings = "settings.ignoredProcessSubstrings"
        let previousLocalHostName = "settings.previousLocalHostName"
        let shareURLMode = "settings.shareURLMode"
    }
}
