import Foundation

struct SessionScanner {
    /// Çalışan Claude Code process'lerini bulur ve session bilgisi döndürür.
    static func findExistingSessions() -> [DiscoveredSession] {
        var results: [DiscoveredSession] = []

        // lsof ile claude process'lerinin çalışma dizinlerini bul
        // ps ile claude process'lerini tara
        guard let output = runCommand("/bin/ps", arguments: ["aux"]) else { return [] }

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            // Claude Code CLI process'lerini bul
            guard line.contains("claude") || line.contains("Claude") else { continue }
            // Kendi bridge process'imizi atla
            guard !line.contains("notchpilot-bridge") else { continue }
            // Xcode/build process'lerini atla
            guard !line.contains("xcodebuild"), !line.contains("SourceKit") else { continue }

            // PID'yi çıkar
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count > 1, let pid = Int(parts[1]) else { continue }

            // Process'in çalışma dizinini bul
            let cwd = getProcessCwd(pid: pid)

            let sessionId = "existing-\(pid)"
            let title = cwd.map { URL(fileURLWithPath: $0).lastPathComponent + " — Claude Code" } ?? "Claude Code (PID: \(pid))"

            // Duplicate kontrolü
            if !results.contains(where: { $0.pid == pid }) {
                results.append(DiscoveredSession(
                    pid: pid,
                    sessionId: sessionId,
                    title: title,
                    cwd: cwd
                ))
            }
        }

        return results
    }

    private static func getProcessCwd(pid: Int) -> String? {
        // lsof ile process'in çalışma dizinini bul
        guard let output = runCommand("/usr/sbin/lsof", arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]) else {
            return nil
        }

        // lsof çıktısından dizin yolunu parse et
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("n") && line.count > 1 {
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
