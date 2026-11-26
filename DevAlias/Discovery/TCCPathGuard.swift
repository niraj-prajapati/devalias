import Foundation

/// Avoid FileManager reads under folders that trigger macOS TCC prompts
/// (Desktop / Documents / Downloads / iCloud). Path **strings** from `lsof` are fine;
/// opening `package.json` or listing the directory is what shows “Allow Desktop”.
enum TCCPathGuard {
    static func isProtectedDirectory(_ path: String) -> Bool {
        let home = NSHomeDirectory()
        let normalized = (path as NSString).standardizingPath
        let prefixes = [
            home + "/Desktop",
            home + "/Documents",
            home + "/Downloads",
            home + "/Library/Mobile Documents",
            home + "/Library/CloudStorage",
        ]
        return prefixes.contains { normalized == $0 || normalized.hasPrefix($0 + "/") }
    }

    /// True if reading files here may prompt the user.
    static func shouldSkipFilesystemProbe(_ path: String) -> Bool {
        isProtectedDirectory(path)
    }
}
