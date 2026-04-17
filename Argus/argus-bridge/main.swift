import Foundation

// argus-bridge: AI coding agent hook → Argus app bridge
//
// Usage: argus-bridge <event-type> [--source claude|codex|gemini|cursor] [--session-id <id>]
// Reads JSON from stdin, sends to Unix socket, optionally waits for response.

func main() -> Int32 {
    let args = CommandLine.arguments

    guard args.count >= 2 else {
        fputs("Usage: argus-bridge <event-type> [--source <agent>] [--session-id <id>]\n", stderr)
        return 1
    }

    let eventType = args[1]

    // Parse --source (default: claude)
    var source = "claude"
    if let idx = args.firstIndex(of: "--source"), idx + 1 < args.count {
        source = args[idx + 1]
    }

    // Parse --session-id
    var sessionId: String?
    if let idx = args.firstIndex(of: "--session-id"), idx + 1 < args.count {
        sessionId = args[idx + 1]
    }

    // Read stdin
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    let stdinJSON = String(data: stdinData, encoding: .utf8) ?? "{}"

    // Build message
    guard let message = EventRouter.buildMessage(
        eventType: eventType,
        source: source,
        stdinJSON: stdinJSON,
        sessionId: sessionId
    ) else {
        fputs("[argus-bridge] Failed to build message\n", stderr)
        return 1
    }

    // Connect to socket — if Argus isn't running, exit silently so the agent
    // doesn't show hook errors on every event.
    let client = SocketClient()
    do {
        try client.connect()
    } catch {
        return 0
    }

    defer { client.disconnect() }

    // Send event
    do {
        try client.send(message)
    } catch {
        return 0
    }

    // For blocking events, wait for response
    if EventRouter.isBlocking(eventType) {
        do {
            let response = try client.readResponse()
            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responsePayload = json["response"] {
                let outputData = try JSONSerialization.data(withJSONObject: responsePayload)
                if let output = String(data: outputData, encoding: .utf8) {
                    print(output)
                }
            }
        } catch {
            return 0
        }
    }

    return 0
}

exit(main())
