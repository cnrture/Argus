import Foundation

final class HookInstaller {
    enum InstallResult {
        case installed
        case alreadyInstalled
        case failed(Error)
    }

    enum UninstallResult {
        case removed
        case notInstalled
        case failed(Error)
    }

    private let settingsPath: String
    private let backupPath: String
    private let bridgeSourcePath: String
    private let bridgeDestDir: String
    private let bridgeDestPath: String

    init() {
        let home = NSHomeDirectory()
        settingsPath = home + "/.claude/settings.json"
        backupPath = home + "/.claude/settings.json.notchpilot-backup"
        bridgeDestDir = home + "/.notchpilot/bin"
        bridgeDestPath = bridgeDestDir + "/notchpilot-bridge"

        // Bridge binary from app bundle Resources
        bridgeSourcePath = Bundle.main.path(forResource: "notchpilot-bridge", ofType: nil) ?? ""
    }

    // MARK: - Hook Installation

    func installHooks() -> InstallResult {
        do {
            let json = try readSettings()

            if HookConfigMerger.hasNotchPilotHooks(in: json) {
                // Update existing hooks (version upgrade)
                let merged = HookConfigMerger.merge(into: json)
                try writeSettings(merged)
                return .alreadyInstalled
            }

            // Backup before modifying
            try backupSettings()

            let merged = HookConfigMerger.merge(into: json)
            try writeSettings(merged)
            return .installed
        } catch {
            // Restore from backup on failure
            restoreFromBackup()
            return .failed(error)
        }
    }

    func uninstallHooks() -> UninstallResult {
        do {
            let json = try readSettings()

            guard HookConfigMerger.hasNotchPilotHooks(in: json) else {
                return .notInstalled
            }

            let cleaned = HookConfigMerger.remove(from: json)
            try writeSettings(cleaned)
            return .removed
        } catch {
            return .failed(error)
        }
    }

    func hooksAreInstalled() -> Bool {
        guard let json = try? readSettings() else { return false }
        return HookConfigMerger.hasNotchPilotHooks(in: json)
    }

    // MARK: - Bridge Binary

    func installBridge() -> Bool {
        let fm = FileManager.default

        // Create destination directory
        try? fm.createDirectory(atPath: bridgeDestDir, withIntermediateDirectories: true)

        // Find bridge binary - check bundle first, then built products
        var sourcePath = bridgeSourcePath

        if sourcePath.isEmpty || !fm.fileExists(atPath: sourcePath) {
            // Fallback: find bridge binary next to the main executable
            if let execURL = Bundle.main.executableURL {
                let candidatePath = execURL.deletingLastPathComponent().appendingPathComponent("notchpilot-bridge").path
                if fm.fileExists(atPath: candidatePath) {
                    sourcePath = candidatePath
                }
            }
        }

        guard !sourcePath.isEmpty, fm.fileExists(atPath: sourcePath) else {
            print("[HookInstaller] Bridge binary not found in bundle")
            return false
        }

        // Copy (overwrite if exists)
        do {
            if fm.fileExists(atPath: bridgeDestPath) {
                try fm.removeItem(atPath: bridgeDestPath)
            }
            try fm.copyItem(atPath: sourcePath, toPath: bridgeDestPath)

            // Make executable
            chmod(bridgeDestPath, 0o755)
            return true
        } catch {
            print("[HookInstaller] Bridge install failed: \(error)")
            return false
        }
    }

    // MARK: - Settings File I/O

    private func readSettings() throws -> [String: Any] {
        let fm = FileManager.default

        // Ensure ~/.claude/ directory exists
        let claudeDir = (settingsPath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: claudeDir) {
            try fm.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        }

        guard fm.fileExists(atPath: settingsPath) else {
            return [:]
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func writeSettings(_ json: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
    }

    private func backupSettings() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: settingsPath) else { return }

        if fm.fileExists(atPath: backupPath) {
            try fm.removeItem(atPath: backupPath)
        }
        try fm.copyItem(atPath: settingsPath, toPath: backupPath)
    }

    private func restoreFromBackup() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupPath) else { return }
        try? fm.removeItem(atPath: settingsPath)
        try? fm.copyItem(atPath: backupPath, toPath: settingsPath)
        print("[HookInstaller] Restored settings from backup")
    }
}
