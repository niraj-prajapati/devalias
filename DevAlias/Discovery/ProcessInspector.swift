import Foundation

enum ProcessInspector {
    /// Best-effort cwd for a PID via `lsof -a -p PID -d cwd -Fn`.
    static func currentWorkingDirectory(pid: Int32) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            if line.hasPrefix("n") {
                let path = String(line.dropFirst())
                if !path.isEmpty { return path }
            }
        }
        return nil
    }

    /// package.json `name` if present at cwd (or parents up to 3 levels).
    /// Skips Desktop/Documents/Downloads so discovery does not trigger TCC prompts.
    static func packageJSONName(near directory: String) -> String? {
        if TCCPathGuard.shouldSkipFilesystemProbe(directory) { return nil }
        var url = URL(fileURLWithPath: directory)
        for _ in 0 ..< 4 {
            if TCCPathGuard.shouldSkipFilesystemProbe(url.path) { break }
            let pkg = url.appendingPathComponent("package.json")
            if let name = readPackageName(at: pkg) {
                return name
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return nil
    }

    static func projectName(pid: Int32?, processName: String) -> String {
        guard let pid, let cwd = currentWorkingDirectory(pid: pid) else {
            return processName
        }
        // Folder name from the path string does not require TCC; reading files does.
        if let pkg = packageJSONName(near: cwd), !pkg.isEmpty {
            return pkg
        }
        let base = URL(fileURLWithPath: cwd).lastPathComponent
        if !base.isEmpty, base != "/", base != "Desktop", base != "Documents", base != "Downloads" {
            return base
        }
        return processName
    }

    private static func readPackageName(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              !name.isEmpty
        else {
            return nil
        }
        return name
    }
}
