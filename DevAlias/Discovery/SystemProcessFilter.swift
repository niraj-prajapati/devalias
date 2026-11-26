import Darwin
import Foundation

/// Filters listen sockets down to likely local **dev** servers (not every macOS daemon / IDE helper).
enum SystemProcessFilter {
    /// Process names we always treat as interesting (basename, lowercased).
    static let developerAllowlist: Set<String> = [
        "node", "nodejs", "npm", "npx", "yarn", "pnpm", "bun", "deno",
        "python", "python3", "uvicorn", "gunicorn", "hypercorn", "daphne",
        "ruby", "rails", "puma", "rackup", "sidekiq",
        "php", "php-fpm",
        "java", "kotlin", "gradle", "mvn",
        "go", "air",
        "cargo", "rustc",
        "dotnet",
        "caddy", "nginx", "httpd", "apache2",
        "next-server", "vite",
        "webpack", "webpack-dev-server", "esbuild",
        "http-server", "serve",
        "redis-server", "postgres", "mysql", "mysqld", "mongod",
        "wrangler",
        "dart", "flutter", "dartaotruntime",
    ]

    static let denylistNames: Set<String> = [
        "controlcenter", "controlce", "controlcenteragent",
        "rapportd", "airplayxpchelper", "airplayuiagent",
        "mdnsresponder", "sharingd", "remoted", "remotepairingd",
        "devalias", "identityservicesd", "apsd", "cloudd",
        "useractivityd", "telephonyutilitieserver", "callservicesd",
        "bluetoothd", "wifiawod", "wifip2pd", "neagent",
        "sentry", "figma", "figma_agent", "spotify", "discord",
        "slack", "zoom.us", "chrome", "google chrome", "chromedriver",
        "code helper", "cursor helper", "electron",
        "webkit", "safaridriver",
        // IDE / AI / device tooling — often inherit a project cwd and fake “dev servers”
        "adb", "adb.exe",
        "jetbrains", "jetbrains-toolbox", "idea", "idea64", "goland", "webstorm", "phpstorm",
        "claude", "claude-code",
        "cursor", "code",
        "copilot", "github-copilot",
    ]

    static let systemPathPrefixes = [
        "/System/",
        "/usr/libexec/",
        "/usr/sbin/",
        "/sbin/",
        "/Library/Apple/",
        "/usr/lib/",
    ]

    /// Cursor / agent helpers often show as versioned binaries like `2.1.330`.
    private static let versionedAgentName = try! NSRegularExpression(
        pattern: #"^\d+(\.\d+){1,3}$"#
    )

    static func executablePath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let result = buffer.withUnsafeMutableBufferPointer { buf -> Int32 in
            guard let base = buf.baseAddress else { return -1 }
            return proc_pidpath(pid, base, UInt32(buf.count))
        }
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    static func isSystemExecutable(_ path: String?) -> Bool {
        guard let path else { return false }
        return systemPathPrefixes.contains { path.hasPrefix($0) }
    }

    static func basename(_ processName: String) -> String {
        (processName as NSString).lastPathComponent.lowercased()
    }

    static func isVersionedAgentName(_ processName: String) -> Bool {
        let base = basename(processName)
        let range = NSRange(base.startIndex..<base.endIndex, in: base)
        return versionedAgentName.firstMatch(in: base, options: [], range: range) != nil
    }

    /// Exact match for short tokens; substring only for longer names (avoids `code` ⊂ `encode`).
    static func matchesDenylist(_ base: String) -> Bool {
        for name in denylistNames {
            if base == name { return true }
            if base.hasPrefix(name + "-") || base.hasPrefix(name + ".") { return true }
            if name.count >= 5, base.contains(name) { return true }
        }
        return false
    }

    /// Hard denylist / system paths / ignored ports / agent binaries.
    static func shouldHide(
        processName: String,
        port: Int,
        pid: Int32? = nil,
        ignoredPorts: [Int] = [],
        ignoredProcessSubstrings: [String] = []
    ) -> Bool {
        if ignoredPorts.contains(port) { return true }
        if [5000, 7000].contains(port) { return true } // AirPlay noise on many Macs
        if port == 5037 { return true } // adb

        let base = basename(processName)
        let lowered = processName.lowercased()
        for raw in ignoredProcessSubstrings {
            let needle = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !needle.isEmpty else { continue }
            if base.contains(needle) || lowered.contains(needle) { return true }
        }
        // Dart VM service / Observatory — not a browseable app
        if (base == "dart" || base.hasPrefix("dart") || base == "flutter"),
           [8181, 9100, 9101, 9102].contains(port)
        {
            return true
        }
        if isVersionedAgentName(base) { return true }
        if matchesDenylist(base) { return true }
        if let pid, let path = executablePath(pid: pid) {
            if isSystemExecutable(path) { return true }
            let lower = path.lowercased()
            // Cursor / VS Code / JetBrains helpers living under Applications
            if lower.contains("/cursor.app/") || lower.contains("/visual studio code.app/") {
                return true
            }
            if lower.contains("/jetbrains ") || lower.contains("/jetbrains/") {
                return true
            }
            if lower.contains("/claude.app/") || lower.hasSuffix("/claude") {
                return true
            }
        }
        return false
    }

    /// After denylist — keep only allowlisted runtimes or stacks inferred from the **process**, not cwd alone.
    static func isLikelyDevServer(processName: String, projectName: String, stack: TechStack) -> Bool {
        _ = projectName // kept for API symmetry / future heuristics
        let base = basename(processName)
        if developerAllowlist.contains(base) { return true }
        if developerAllowlist.contains(where: { base.hasPrefix($0 + "-") || base.hasPrefix($0 + ".") }) {
            return true
        }
        // Known stack only counts when process itself looks like a runtime (StackHeuristics already gated).
        if stack != .unknown { return true }
        return false
    }

    static func filter(
        _ sockets: [ListenSocket],
        ignoredPorts: [Int],
        ignoredProcessSubstrings: [String] = []
    ) -> [ListenSocket] {
        sockets.filter {
            !shouldHide(
                processName: $0.processName,
                port: $0.port,
                pid: $0.pid,
                ignoredPorts: ignoredPorts,
                ignoredProcessSubstrings: ignoredProcessSubstrings
            )
        }
    }
}
