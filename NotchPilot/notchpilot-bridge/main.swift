import Foundation

// notchpilot-bridge: Claude Code hook → NotchPilot app bridge
//
// Usage: notchpilot-bridge <event-type> [--session-id <id>]
// Reads JSON from stdin, sends to Unix socket, optionally waits for response.

func main() -> Int32 {
    let args = CommandLine.arguments

    guard args.count >= 2 else {
        fputs("Usage: notchpilot-bridge <event-type> [--session-id <id>]\n", stderr)
        return 1
    }

    let eventType = args[1]

    // Parse optional session-id
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
        stdinJSON: stdinJSON,
        sessionId: sessionId
    ) else {
        fputs("[notchpilot-bridge] Failed to build message\n", stderr)
        return 1
    }

    // Connect to socket
    let client = SocketClient()
    do {
        try client.connect()
    } catch {
        // App not running — exit silently for non-blocking events
        if EventRouter.isBlocking(eventType) {
            fputs("[notchpilot-bridge] Cannot connect to NotchPilot: \(error)\n", stderr)
        }
        return 1
    }

    defer { client.disconnect() }

    // Send event
    do {
        try client.send(message)
    } catch {
        fputs("[notchpilot-bridge] Send failed: \(error)\n", stderr)
        return 1
    }

    // For blocking events, wait for response
    if EventRouter.isBlocking(eventType) {
        do {
            let response = try client.readResponse()
            // Extract the response payload and write to stdout
            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responsePayload = json["response"] {
                let outputData = try JSONSerialization.data(withJSONObject: responsePayload)
                if let output = String(data: outputData, encoding: .utf8) {
                    print(output)
                }
            }
        } catch {
            fputs("[notchpilot-bridge] Read response failed: \(error)\n", stderr)
            return 1
        }
    }

    return 0
}

exit(main())
