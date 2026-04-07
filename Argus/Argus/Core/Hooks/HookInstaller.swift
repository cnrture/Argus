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

    private let bridgeDestDir: String
    private let bridgeDestPath: String

    init() {
        let home = NSHomeDirectory()
        bridgeDestDir = home + "/.argus/bin"
        bridgeDestPath = bridgeDestDir + "/argus-bridge"
    }

    // MARK: - Multi-Agent Hook Installation

    func installHooks(for agents: [AgentSource] = AgentSource.allCases) -> [AgentSource: InstallResult] {
        var results: [AgentSource: InstallResult] = [:]
        for agent in agents {
            results[agent] = installHooks(for: agent)
        }
        return results
    }

    func installHooks(for agent: AgentSource) -> InstallResult {
        // CLI dizini yoksa atla — kullanıcıda o CLI kurulu değil
        let configDir = (agent.configPath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: configDir) {
            return .installed // Sessizce atla
        }

        do {
            let json = try readJSON(at: agent.configPath)

            if HookConfigMerger.hasArgusHooks(in: json, for: agent) {
                let merged = HookConfigMerger.merge(into: json, for: agent)
                try writeJSON(merged, to: agent.configPath)
                return .alreadyInstalled
            }

            // Backup
            backupFile(at: agent.configPath)

            // Codex needs hooks enabled in config.toml
            if agent == .codex {
                enableCodexHooks()
            }

            let merged = HookConfigMerger.merge(into: json, for: agent)
            try writeJSON(merged, to: agent.configPath)
            return .installed
        } catch {
            return .failed(error)
        }
    }

    func uninstallHooks(for agents: [AgentSource] = AgentSource.allCases) -> [AgentSource: UninstallResult] {
        var results: [AgentSource: UninstallResult] = [:]
        for agent in agents {
            results[agent] = uninstallHooks(for: agent)
        }
        return results
    }

    func uninstallHooks(for agent: AgentSource) -> UninstallResult {
        do {
            let json = try readJSON(at: agent.configPath)
            guard HookConfigMerger.hasArgusHooks(in: json, for: agent) else {
                return .notInstalled
            }
            let cleaned = HookConfigMerger.remove(from: json, for: agent)
            try writeJSON(cleaned, to: agent.configPath)
            return .removed
        } catch {
            return .failed(error)
        }
    }

    func hooksAreInstalled(for agent: AgentSource) -> Bool {
        guard let json = try? readJSON(at: agent.configPath) else { return false }
        return HookConfigMerger.hasArgusHooks(in: json, for: agent)
    }

    /// Convenience: check if ANY agent has hooks installed
    func hooksAreInstalled() -> Bool {
        AgentSource.allCases.contains { hooksAreInstalled(for: $0) }
    }

    // MARK: - Verify & Repair

    /// Eksik hook'ları onarır, fazlaları kaldırır. Enabled agents listesine göre.
    func verifyAndRepair(enabledAgents: Set<String>) -> [String] {
        var repaired: [String] = []

        for agent in AgentSource.allCases {
            let shouldBeInstalled = enabledAgents.contains(agent.rawValue)
            let configDir = (agent.configPath as NSString).deletingLastPathComponent

            // CLI kurulu değilse atla
            guard FileManager.default.fileExists(atPath: configDir) else { continue }

            let isInstalled = hooksAreInstalled(for: agent)

            if shouldBeInstalled && !isInstalled {
                let result = installHooks(for: agent)
                if case .installed = result { repaired.append(agent.displayName) }
                if case .alreadyInstalled = result { repaired.append(agent.displayName) }
            } else if !shouldBeInstalled && isInstalled {
                _ = uninstallHooks(for: agent)
            }
        }

        // Bridge binary'yi de güncelle
        _ = installBridge()

        return repaired
    }

    // MARK: - Bridge Binary

    func installBridge() -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: bridgeDestDir, withIntermediateDirectories: true)

        var sourcePath = Bundle.main.path(forResource: "argus-bridge", ofType: nil) ?? ""
        if sourcePath.isEmpty || !fm.fileExists(atPath: sourcePath) {
            if let execURL = Bundle.main.executableURL {
                let candidate = execURL.deletingLastPathComponent().appendingPathComponent("argus-bridge").path
                if fm.fileExists(atPath: candidate) { sourcePath = candidate }
            }
        }

        guard !sourcePath.isEmpty, fm.fileExists(atPath: sourcePath) else { return false }

        do {
            if fm.fileExists(atPath: bridgeDestPath) { try fm.removeItem(atPath: bridgeDestPath) }
            try fm.copyItem(atPath: sourcePath, toPath: bridgeDestPath)
            chmod(bridgeDestPath, 0o755)
            return true
        } catch {
            print("[Argus] Bridge install failed: \(error)")
            return false
        }
    }

    // MARK: - Codex Specific

    private func enableCodexHooks() {
        let configPath = NSHomeDirectory() + "/.codex/config.toml"
        let fm = FileManager.default

        let dir = (configPath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: dir) {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: configPath) {
            if var content = try? String(contentsOfFile: configPath, encoding: .utf8) {
                if !content.contains("codex_hooks") {
                    content += "\n[features]\ncodex_hooks = true\n"
                    try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
                }
            }
        } else {
            try? "[features]\ncodex_hooks = true\n".write(toFile: configPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - File I/O

    private func readJSON(at path: String) throws -> [String: Any] {
        let fm = FileManager.default
        let dir = (path as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        guard fm.fileExists(atPath: path) else { return [:] }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func writeJSON(_ json: [String: Any], to path: String) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func backupFile(at path: String) {
        let backup = path + ".argus-backup"
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        try? fm.removeItem(atPath: backup)
        try? fm.copyItem(atPath: path, toPath: backup)
    }
}
