import Foundation

struct HookConfigMerger {
    static let bridgeCommand = "~/.notchpilot/bin/notchpilot-bridge"
    static let marker = "notchpilot-bridge"

    struct HookEntry {
        let eventName: String
        let command: String
        let timeout: Int
    }

    static let hookEntries: [HookEntry] = [
        HookEntry(eventName: "SessionStart",      command: "\(bridgeCommand) session-start",      timeout: 5),
        HookEntry(eventName: "SessionEnd",         command: "\(bridgeCommand) session-end",        timeout: 5),
        HookEntry(eventName: "Stop",               command: "\(bridgeCommand) stop",               timeout: 5),
        HookEntry(eventName: "PreToolUse",         command: "\(bridgeCommand) pre-tool-use",       timeout: 5),
        HookEntry(eventName: "PostToolUse",        command: "\(bridgeCommand) post-tool-use",      timeout: 5),
        HookEntry(eventName: "PermissionRequest",  command: "\(bridgeCommand) permission-request", timeout: 86400),
        HookEntry(eventName: "Notification",       command: "\(bridgeCommand) notification",       timeout: 5),
        HookEntry(eventName: "UserPromptSubmit",   command: "\(bridgeCommand) user-prompt-submit", timeout: 5),
        HookEntry(eventName: "PreCompact",         command: "\(bridgeCommand) pre-compact",        timeout: 5),
        HookEntry(eventName: "SubagentStop",       command: "\(bridgeCommand) subagent-stop",      timeout: 5),
    ]

    /// Mevcut settings JSON'a NotchPilot hook'larını merge eder.
    /// Mevcut hook'lara dokunmaz, sadece NotchPilot hook'larını ekler/günceller.
    static func merge(into existingJSON: [String: Any]) -> [String: Any] {
        var result = existingJSON
        var hooks = result["hooks"] as? [String: Any] ?? [:]

        for entry in hookEntries {
            var eventArray = hooks[entry.eventName] as? [[String: Any]] ?? []

            let notchpilotHook: [String: Any] = [
                "type": "command",
                "command": entry.command,
                "timeout": entry.timeout
            ]

            let hookWrapper: [String: Any] = [
                "matcher": "",
                "hooks": [notchpilotHook]
            ]

            // Mevcut NotchPilot hook'u bul
            if let existingIndex = eventArray.firstIndex(where: { wrapper in
                guard let innerHooks = wrapper["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { hook in
                    (hook["command"] as? String)?.contains(marker) == true
                }
            }) {
                // Güncelle (versiyon yükseltme durumu)
                eventArray[existingIndex] = hookWrapper
            } else {
                // Sonuna ekle (mevcut hook'ların önceliği korunur)
                eventArray.append(hookWrapper)
            }

            hooks[entry.eventName] = eventArray
        }

        result["hooks"] = hooks
        return result
    }

    /// NotchPilot hook'larını kaldırır, diğer hook'lara dokunmaz.
    static func remove(from existingJSON: [String: Any]) -> [String: Any] {
        var result = existingJSON
        guard var hooks = result["hooks"] as? [String: Any] else { return result }

        for entry in hookEntries {
            guard var eventArray = hooks[entry.eventName] as? [[String: Any]] else { continue }

            eventArray.removeAll { wrapper in
                guard let innerHooks = wrapper["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { hook in
                    (hook["command"] as? String)?.contains(marker) == true
                }
            }

            if eventArray.isEmpty {
                hooks.removeValue(forKey: entry.eventName)
            } else {
                hooks[entry.eventName] = eventArray
            }
        }

        if (hooks as NSDictionary).count == 0 {
            result.removeValue(forKey: "hooks")
        } else {
            result["hooks"] = hooks
        }

        return result
    }

    /// Mevcut settings'te NotchPilot hook'ları var mı kontrol eder.
    static func hasNotchPilotHooks(in json: [String: Any]) -> Bool {
        guard let hooks = json["hooks"] as? [String: Any] else { return false }
        for (_, value) in hooks {
            guard let eventArray = value as? [[String: Any]] else { continue }
            for wrapper in eventArray {
                guard let innerHooks = wrapper["hooks"] as? [[String: Any]] else { continue }
                if innerHooks.contains(where: { ($0["command"] as? String)?.contains(marker) == true }) {
                    return true
                }
            }
        }
        return false
    }
}
