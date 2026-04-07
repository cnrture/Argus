import AppKit

struct WindowJumper {
    static func jumpToSession(_ session: Session) {
        if let bundleID = session.ownerBundleID {
            activateApp(bundleIdentifier: bundleID)
            return
        }
        if let cwd = session.cwd {
            if let app = findAppByCwd(cwd) {
                activateApp(app: app)
                return
            }
        }
        activateFallbackTerminal()
    }

    static func detectOwnerApp(for session: Session, pid: Int? = nil) {
        let targetPID = pid ?? findClaudePID(sessionCwd: session.cwd)
        guard let targetPID else { return }
        session.ownerPID = targetPID

        // Parent PID zincirinde executable path'ten app bul
        var currentPID = targetPID
        for _ in 0..<10 {
            let parentPID = getParentPID(currentPID)
            if parentPID <= 1 { break }

            // Executable path'ten .app bundle'ı çıkar
            if let execPath = getProcessExecPath(parentPID),
               let bundleID = bundleIDFromExecPath(execPath) {
                session.ownerBundleID = bundleID
                return
            }
            currentPID = parentPID
        }

        // Fallback: çalışan tüm bilinen app'leri kontrol et
        for bundleID in knownBundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
               !app.isTerminated {
                session.ownerBundleID = bundleID
                return
            }
        }
    }

    // MARK: - Private

    private static func activateApp(bundleIdentifier: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            app.activate()
        }
    }

    private static func activateApp(app: NSRunningApplication) {
        app.activate()
    }

    private static func findAppByCwd(_ cwd: String) -> NSRunningApplication? {
        for bundleID in knownBundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
               !app.isTerminated {
                return app
            }
        }
        return nil
    }

    private static func activateFallbackTerminal() {
        let terminals = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable",
        ]
        for bundleID in terminals {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
               !app.isTerminated {
                app.activate()
                return
            }
        }
    }

    /// Executable path'ten .app bundle'ını bulup bundle ID'yi çıkar
    private static func bundleIDFromExecPath(_ path: String) -> String? {
        // "/Applications/Android Studio.app/Contents/MacOS/studio" → ".app" bul
        var current = path
        while !current.isEmpty {
            if current.hasSuffix(".app") {
                if let bundle = Bundle(path: current) {
                    return bundle.bundleIdentifier
                }
            }
            // Bir üst dizine git
            let parent = (current as NSString).deletingLastPathComponent
            if parent == current { break }
            current = parent
        }
        return nil
    }

    private static func getProcessExecPath(_ pid: Int) -> String? {
        guard let output = runShell("/bin/ps", args: ["-o", "comm=", "-p", "\(pid)"]) else { return nil }
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private static func findClaudePID(sessionCwd: String?) -> Int? {
        guard let output = runShell("/usr/bin/pgrep", args: ["-x", "claude"]) else { return nil }
        let pids = output.split(separator: "\n").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if let cwd = sessionCwd {
            for pid in pids {
                if let pidCwd = getProcessCwd(pid), pidCwd == cwd { return pid }
            }
        }
        return pids.first
    }

    private static func getParentPID(_ pid: Int) -> Int {
        guard let output = runShell("/bin/ps", args: ["-o", "ppid=", "-p", "\(pid)"]) else { return 0 }
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func getProcessCwd(_ pid: Int) -> String? {
        guard let output = runShell("/usr/sbin/lsof", args: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]) else { return nil }
        for line in output.split(separator: "\n") {
            if line.hasPrefix("n/") { return String(line.dropFirst()) }
        }
        return nil
    }

    private static func runShell(_ path: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch { return nil }
    }

    private static let knownBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.google.android.studio",
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.pycharm",
        "com.jetbrains.WebStorm",
        "com.jetbrains.fleet",
    ]
}
