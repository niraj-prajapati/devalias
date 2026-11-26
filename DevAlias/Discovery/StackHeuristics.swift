import Foundation

/// Best-effort stack badge from process name + cwd files (FULL-PRODUCT §4.7).
enum StackHeuristics {
    struct Context: Equatable {
        var processName: String
        var cwd: String?
        /// File basenames found in cwd (and optionally parents) for tests/fixtures.
        var filenames: Set<String>
    }

    static func infer(processName: String, pid: Int32?) -> TechStack {
        let cwd = pid.flatMap { ProcessInspector.currentWorkingDirectory(pid: $0) }
        let files = cwd.map { listRelevantFiles(near: $0) } ?? []
        return infer(Context(processName: processName, cwd: cwd, filenames: Set(files)))
    }

    static func infer(_ context: Context) -> TechStack {
        let proc = (context.processName as NSString).lastPathComponent.lowercased()
        let files = context.filenames.map { $0.lowercased() }

        if proc.contains("docker") || proc.contains("vpnkit") || proc == "com.docker.backend" {
            return .docker
        }
        if files.contains(where: { $0.hasPrefix("vite.config.") }) {
            return .vite
        }
        if files.contains("next.config.js")
            || files.contains("next.config.mjs")
            || files.contains("next.config.ts")
            || files.contains("next.config.mt.js")
        {
            return .next
        }
        if proc.contains("python") || proc.contains("uvicorn") || proc.contains("gunicorn")
            || files.contains("uvicorn") || files.contains("fastapi")
        {
            // Prefer python even for node-less API dirs
            if proc.contains("python") || proc.contains("uvicorn") || proc.contains("gunicorn") {
                return .python
            }
        }
        if proc == "php" || proc.hasPrefix("php-") {
            return .php
        }
        if proc.contains("ruby") || proc.contains("puma") || proc.contains("rack") {
            return .ruby
        }
        if proc.hasSuffix("_darwin") || proc.hasSuffix("_darwin_arm64") || proc == "air"
            || (proc.count > 2 && !["node", "npm", "yarn", "pnpm", "bun", "deno"].contains(proc)
                && files.contains("go.mod"))
        {
            if files.contains("go.mod") || proc.contains("go") || proc == "air" {
                return .go
            }
        }
        // Only attribute JS stacks to JS runtimes — never from cwd alone
        // (IDE/AI helpers often inherit a project cwd with package.json).
        let jsRuntimes: Set<String> = [
            "node", "nodejs", "bun", "deno", "npm", "npx", "yarn", "pnpm",
            "next-server", "vite", "webpack", "webpack-dev-server", "esbuild",
            "http-server", "serve",
        ]
        if jsRuntimes.contains(proc) {
            if files.contains(where: { $0.hasPrefix("vite.config.") }) { return .vite }
            if files.contains(where: { $0.hasPrefix("next.config.") }) { return .next }
            return .node
        }
        if proc == "dart" || proc.hasPrefix("dart") || proc == "flutter" {
            return .unknown // allowlisted via process name; no dedicated badge yet
        }
        // Cwd markers only for allowlisted-looking binaries already handled above;
        // do not promote random processes just because they sit in a repo.
        return .unknown
    }

    private static func listRelevantFiles(near directory: String) -> [String] {
        // Listing Desktop/Documents/Downloads triggers “Allow access” on every hub start.
        if TCCPathGuard.shouldSkipFilesystemProbe(directory) { return [] }

        var names: [String] = []
        var url = URL(fileURLWithPath: directory)
        let interestingPrefixes = ["vite.config.", "next.config."]
        let interestingExact: Set<String> = [
            "package.json", "go.mod", "composer.json", "index.php", "Gemfile",
            "requirements.txt", "pyproject.toml", "Dockerfile",
        ]
        for _ in 0 ..< 3 {
            if TCCPathGuard.shouldSkipFilesystemProbe(url.path) { break }
            if let items = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
                for item in items {
                    if interestingExact.contains(item) || interestingExact.contains(item.lowercased()) {
                        names.append(item)
                    }
                    for prefix in interestingPrefixes where item.lowercased().hasPrefix(prefix) {
                        names.append(item)
                    }
                }
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return names
    }
}
