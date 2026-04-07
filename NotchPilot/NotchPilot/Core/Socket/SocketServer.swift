import Foundation

protocol SocketServerDelegate: AnyObject {
    func socketServer(_ server: SocketServer, didReceiveEvent event: HookEvent, respond: @escaping (SocketResponse) -> Void)
}

struct HookEvent: Codable, Identifiable {
    let id: String
    let event: HookEventType
    let timestamp: Date?
    let sessionId: String
    let cwd: String?
    let data: HookEventData?
}

enum HookEventType: String, Codable {
    case sessionStart = "session-start"
    case sessionEnd = "session-end"
    case stop
    case preToolUse = "pre-tool-use"
    case postToolUse = "post-tool-use"
    case permissionRequest = "permission-request"
    case notification
    case userPromptSubmit = "user-prompt-submit"
    case preCompact = "pre-compact"
    case subagentStop = "subagent-stop"
}

struct HookEventData: Codable {
    let sessionId: String?
    let toolName: String?
    let toolInput: [String: AnyCodableValue]?
    let toolUseId: String?
    let hookEventName: String?
}

struct SocketResponse: Codable {
    let id: String
    let response: ResponsePayload?
}

struct ResponsePayload: Codable {
    let hookSpecificOutput: HookSpecificOutput?
}

struct HookSpecificOutput: Codable {
    let hookEventName: String?
    let decision: PermissionDecision?
    let selectedOption: String?
}

struct PermissionDecision: Codable {
    let behavior: String  // "allow" or "deny"
    let reason: String?
}

// Simple any-value wrapper for JSON
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

final class SocketServer {
    private let socketPath: String
    private var listenSocket: Int32 = -1
    private var clientSockets: [Int32] = []
    private var listenSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.notchpilot.socket", qos: .userInitiated)

    weak var delegate: SocketServerDelegate?

    init() {
        let dir = NSHomeDirectory() + "/.notchpilot"
        socketPath = dir + "/notchpilot.sock"
        ensureDirectory(dir)
    }

    func start() throws {
        cleanup()

        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket >= 0 else {
            throw SocketError.createFailed
        }

        // Set socket options
        var reuseAddr: Int32 = 1
        setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strcpy(dest, ptr)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(listenSocket)
            throw SocketError.bindFailed
        }

        // Secure permissions: owner only
        chmod(socketPath, 0o600)

        guard listen(listenSocket, 5) == 0 else {
            close(listenSocket)
            throw SocketError.listenFailed
        }

        // Accept connections via GCD
        let source = DispatchSource.makeReadSource(fileDescriptor: listenSocket, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.listenSocket, fd >= 0 {
                close(fd)
            }
        }
        source.resume()
        listenSource = source
    }

    func stop() {
        listenSource?.cancel()
        listenSource = nil
        for fd in clientSockets {
            close(fd)
        }
        clientSockets.removeAll()
        cleanup()
    }

    private func cleanup() {
        unlink(socketPath)
    }

    private func ensureDirectory(_ path: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        // Secure directory permissions
        chmod(path, 0o700)
    }

    private func acceptConnection() {
        var clientAddr = sockaddr_un()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let clientFd = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(listenSocket, $0, &clientAddrLen)
            }
        }

        guard clientFd >= 0 else { return }
        clientSockets.append(clientFd)

        queue.async { [weak self] in
            self?.handleClient(clientFd)
        }
    }

    private func handleClient(_ fd: Int32) {
        var buffer = Data()
        let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 8192)
        defer {
            readBuffer.deallocate()
            close(fd)
            queue.async { [weak self] in
                self?.clientSockets.removeAll { $0 == fd }
            }
        }

        while true {
            let bytesRead = read(fd, readBuffer, 8192)
            if bytesRead <= 0 { break }
            buffer.append(readBuffer, count: bytesRead)

            // Process complete lines
            while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer[buffer.startIndex..<newlineIndex]
                buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }

                processLine(line, clientFd: fd)
            }

            // If no newline but has data, try to process it (single message without trailing newline)
            if !buffer.isEmpty, buffer.firstIndex(of: UInt8(ascii: "\n")) == nil {
                // Wait a bit more for data
                let moreBytesRead = read(fd, readBuffer, 8192)
                if moreBytesRead <= 0 {
                    // End of stream, process remaining
                    if let line = String(data: buffer, encoding: .utf8), !line.isEmpty {
                        processLine(line, clientFd: fd)
                    }
                    break
                } else {
                    buffer.append(readBuffer, count: moreBytesRead)
                }
            }
        }
    }

    private func processLine(_ line: String, clientFd: Int32) {
        do {
            let event = try JSONLParser.parse(line, as: HookEvent.self)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.socketServer(self, didReceiveEvent: event) { response in
                    self.sendResponse(response, to: clientFd)
                }
            }
        } catch {
            // Log parse error but don't crash
            print("[SocketServer] Parse error: \(error) for line: \(line.prefix(200))")
        }
    }

    private func sendResponse(_ response: SocketResponse, to fd: Int32) {
        queue.async {
            do {
                let jsonString = try JSONLParser.encode(response) + "\n"
                if let data = jsonString.data(using: .utf8) {
                    data.withUnsafeBytes { ptr in
                        if let base = ptr.baseAddress {
                            _ = write(fd, base, data.count)
                        }
                    }
                }
            } catch {
                print("[SocketServer] Encode error: \(error)")
            }
        }
    }
}

enum SocketError: Error, LocalizedError {
    case createFailed
    case bindFailed
    case listenFailed

    var errorDescription: String? {
        switch self {
        case .createFailed: "Socket oluşturulamadı"
        case .bindFailed: "Socket bağlanamadı (dosya zaten mevcut olabilir)"
        case .listenFailed: "Socket dinleme başlatılamadı"
        }
    }
}
