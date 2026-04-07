import Foundation

struct EventRouter {
    static let blockingEvents: Set<String> = [
        "permission-request"
    ]

    static func isBlocking(_ eventType: String) -> Bool {
        blockingEvents.contains(eventType)
    }

    static func buildMessage(eventType: String, source: String, stdinJSON: String, sessionId: String?) -> String? {
        guard var json = try? JSONSerialization.jsonObject(with: Data(stdinJSON.utf8)) as? [String: Any] else {
            return nil
        }

        let eventId = "evt_\(UUID().uuidString.prefix(8))"

        var message: [String: Any] = [
            "id": eventId,
            "event": eventType,
            "source": source,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let sid = json["session_id"] as? String {
            message["session_id"] = sid
        } else if let sid = sessionId {
            message["session_id"] = sid
        } else {
            message["session_id"] = "unknown"
        }

        if let cwd = json["cwd"] as? String {
            message["cwd"] = cwd
            json.removeValue(forKey: "cwd")
        }

        message["data"] = json

        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}
