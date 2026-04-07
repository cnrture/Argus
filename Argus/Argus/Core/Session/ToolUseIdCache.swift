import Foundation

final class ToolUseIdCache {
    private var cache: [String: String] = [:]
    private let maxSize = 100

    func store(sessionId: String, toolName: String, toolInput: String, toolUseId: String) {
        let key = makeKey(sessionId: sessionId, toolName: toolName, toolInput: toolInput)
        cache[key] = toolUseId
        pruneIfNeeded()
    }

    func retrieve(sessionId: String, toolName: String, toolInput: String) -> String? {
        let key = makeKey(sessionId: sessionId, toolName: toolName, toolInput: toolInput)
        return cache.removeValue(forKey: key)
    }

    func clearSession(_ sessionId: String) {
        cache = cache.filter { !$0.key.hasPrefix("\(sessionId):") }
    }

    private func makeKey(sessionId: String, toolName: String, toolInput: String) -> String {
        "\(sessionId):\(toolName):\(toolInput)"
    }

    private func pruneIfNeeded() {
        if cache.count > maxSize {
            let keysToRemove = Array(cache.keys.prefix(cache.count - maxSize))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}
