import Foundation

final class SocketClient {
    private let socketPath: String
    private var fd: Int32 = -1

    init() {
        socketPath = NSHomeDirectory() + "/.argus/argus.sock"
    }

    func connect() throws {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BridgeError.socketCreateFailed
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strcpy(dest, ptr)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Foundation.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            close(fd)
            fd = -1
            throw BridgeError.connectFailed
        }
    }

    func send(_ message: String) throws {
        let data = message + "\n"
        guard let bytes = data.data(using: .utf8) else {
            throw BridgeError.encodingError
        }
        let written = bytes.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            return write(fd, base, bytes.count)
        }
        guard written > 0 else {
            throw BridgeError.writeFailed
        }
    }

    func readResponse() throws -> String {
        var buffer = Data()
        let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { readBuf.deallocate() }

        while true {
            let bytesRead = read(fd, readBuf, 4096)
            if bytesRead <= 0 { break }
            buffer.append(readBuf, count: bytesRead)

            if buffer.contains(UInt8(ascii: "\n")) {
                break
            }
        }

        guard let response = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw BridgeError.readFailed
        }
        return response
    }

    func disconnect() {
        if fd >= 0 {
            close(fd)
            fd = -1
        }
    }
}

enum BridgeError: Error {
    case socketCreateFailed
    case connectFailed
    case encodingError
    case writeFailed
    case readFailed
    case invalidArguments
    case stdinReadFailed
}
