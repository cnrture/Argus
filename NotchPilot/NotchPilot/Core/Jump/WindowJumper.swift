import AppKit

struct WindowJumper {
    /// PID'den parent terminal/IDE uygulamasını bulup ön plana getirir.
    static func jumpToSession(_ session: Session) {
        // 1. Bilinen bundleID varsa doğrudan kullan
        if let bundleID = session.ownerBundleID {
            activateApp(bundleIdentifier: bundleID)
            return
        }

        // 2. PID'den parent process'i bul
        if let pid = session.ownerPID {
            if let app = findParentApp(pid: pid) {
                activateApp(app: app)
                return
            }
        }

        // 3. CWD'den açık terminalleri/IDE'leri tara
        if let cwd = session.cwd {
            if let app = findAppByCwd(cwd) {
                activateApp(app: app)
                return
            }
        }

        // 4. Fallback: bilinen terminal uygulamalarını dene
        activateFallbackTerminal()
    }

    /// Session oluşturulurken parent app'i algıla ve kaydet
    static func detectOwnerApp(for session: Session, pid: Int? = nil) {
        let targetPID = pid ?? findClaudePID(sessionCwd: session.cwd)
        guard let targetPID else { return }

        session.ownerPID = targetPID

        // Parent process'i bul (terminal/IDE)
        var currentPID = targetPID
        for _ in 0..<10 { // max 10 seviye yukarı
            let parentPID = getParentPID(currentPID)
            if parentPID <= 1 { break }

            if let app = NSRunningApplication(processIdentifier: pid_t(parentPID)),
               let bundleID = app.bundleIdentifier,
               isKnownTerminalOrIDE(bundleID) {
                session.ownerBundleID = bundleID
                return
            }
            currentPID = parentPID
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

    private static func findParentApp(pid: Int) -> NSRunningApplication? {
        var currentPID = pid
        for _ in 0..<10 {
            let parentPID = getParentPID(currentPID)
            if parentPID <= 1 { break }
            if let app = NSRunningApplication(processIdentifier: pid_t(parentPID)),
               app.bundleIdentifier != nil {
                return app
            }
            currentPID = parentPID
        }
        return nil
    }

    private static func findAppByCwd(_ cwd: String) -> NSRunningApplication? {
        // Bilinen terminal/IDE bundle'larını kontrol et
        let knownApps = [
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
        ]

        for bundleID in knownApps {
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

    private static func findClaudePID(sessionCwd: String?) -> Int? {
        guard let output = runShell("/usr/bin/pgrep", args: ["-x", "claude"]) else { return nil }
        let pids = output.split(separator: "\n").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        if let cwd = sessionCwd {
            for pid in pids {
                if let pidCwd = getProcessCwd(pid), pidCwd == cwd {
                    return pid
                }
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

    private static func isKnownTerminalOrIDE(_ bundleID: String) -> Bool {
        let known: Set<String> = [
            "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
            "dev.warp.Warp-Stable", "io.alacritty", "net.kovidgoyal.kitty",
            "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92",
            "com.google.android.studio", "com.jetbrains.intellij",
            "com.jetbrains.pycharm", "com.jetbrains.WebStorm",
        ]
        return known.contains(bundleID)
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
}
