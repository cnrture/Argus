import Foundation

struct SessionScanner {
    static func findExistingSessions() -> [DiscoveredSession] {
        // pgrep ile claude process'lerini doğrudan bul
        guard let pids = runCommand("/usr/bin/pgrep", arguments: ["-x", "claude"]) else { return [] }

        var results: [DiscoveredSession] = []

        let pidLines = pids.components(separatedBy: "\n").filter { !$0.isEmpty }
        for pidStr in pidLines {
            guard let pid = Int(pidStr.trimmingCharacters(in: .whitespaces)) else { continue }

            let cwd = getProcessCwd(pid: pid)
            let sessionId = "existing-\(pid)"
            let title = cwd.map { URL(fileURLWithPath: $0).lastPathComponent + " — Claude Code" }
                ?? "Claude Code (PID: \(pid))"

            results.append(DiscoveredSession(
                pid: pid,
                sessionId: sessionId,
                title: title,
                cwd: cwd
            ))
        }

        return results
    }

    private static func getProcessCwd(pid: Int) -> String? {
        guard let output = runCommand("/usr/sbin/lsof", arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]) else {
            return nil
        }
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("n/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    private static func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

struct DiscoveredSession {
    let pid: Int
    let sessionId: String
    let title: String
    let cwd: String?
}
