import Foundation

struct HookConfigMerger {
    static let bridgeCommand = "~/.notchpilot/bin/notchpilot-bridge"
    static let marker = "notchpilot-bridge"

    // MARK: - Multi-Agent Merge

    static func merge(into existingJSON: [String: Any], for agent: AgentSource) -> [String: Any] {
        var result = existingJSON
        var hooks = result["hooks"] as? [String: Any] ?? [:]

        for (internalEvent, nativeEvent) in agent.eventMapping {
            let command = "\(bridgeCommand) \(internalEvent) --source \(agent.rawValue)"
            let timeout = (internalEvent == "permission-request" ? 86400 : 5) * agent.timeoutMultiplier

            let hookEntry = buildHookEntry(command: command, timeout: timeout, format: agent.hookFormat)

            var eventArray = hooks[nativeEvent] as? [[String: Any]] ?? []

            if let existingIndex = findNotchPilotHookIndex(in: eventArray, format: agent.hookFormat) {
                eventArray[existingIndex] = hookEntry
            } else {
                eventArray.append(hookEntry)
            }

            hooks[nativeEvent] = eventArray
        }

        result["hooks"] = hooks
        return result
    }

    static func remove(from existingJSON: [String: Any], for agent: AgentSource) -> [String: Any] {
        var result = existingJSON
        guard var hooks = result["hooks"] as? [String: Any] else { return result }

        for (_, nativeEvent) in agent.eventMapping {
            guard var eventArray = hooks[nativeEvent] as? [[String: Any]] else { continue }

            eventArray.removeAll { entry in
                containsNotchPilot(entry: entry, format: agent.hookFormat)
            }

            if eventArray.isEmpty {
                hooks.removeValue(forKey: nativeEvent)
            } else {
                hooks[nativeEvent] = eventArray
            }
        }

        if (hooks as NSDictionary).count == 0 {
            result.removeValue(forKey: "hooks")
        } else {
            result["hooks"] = hooks
        }

        return result
    }

    static func hasNotchPilotHooks(in json: [String: Any], for agent: AgentSource) -> Bool {
        guard let hooks = json["hooks"] as? [String: Any] else { return false }
        for (_, value) in hooks {
            guard let eventArray = value as? [[String: Any]] else { continue }
            for entry in eventArray {
                if containsNotchPilot(entry: entry, format: agent.hookFormat) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Hook Format Builders

    private static func buildHookEntry(command: String, timeout: Int, format: HookFormat) -> [String: Any] {
        switch format {
        case .claude:
            return [
                "matcher": "",
                "hooks": [["type": "command", "command": command, "timeout": timeout]]
            ]
        case .nested:
            return [
                "hooks": [["type": "command", "command": command, "timeout": timeout]]
            ]
        case .flat:
            return ["command": command]
        }
    }

    private static func findNotchPilotHookIndex(in array: [[String: Any]], format: HookFormat) -> Int? {
        array.firstIndex { containsNotchPilot(entry: $0, format: format) }
    }

    private static func containsNotchPilot(entry: [String: Any], format: HookFormat) -> Bool {
        switch format {
        case .claude, .nested:
            guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return innerHooks.contains { ($0["command"] as? String)?.contains(marker) == true }
        case .flat:
            return (entry["command"] as? String)?.contains(marker) == true
        }
    }
}
