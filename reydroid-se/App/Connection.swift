// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import Darwin

enum RDProblem: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

final class Connection {
    private let fd: Int32
    private let writeLock = NSLock()
    private let closeLock = NSLock()
    private var closed = false
    private var buffered = Data()
    init(fd: Int32) { self.fd = fd }
    deinit { close() }

    static func unix(_ path: String, timeout: Int = 20) throws -> Connection {
        guard path.utf8.count < 104 else { throw RDProblem.message("The display socket path is too long.") }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw RDProblem.message("Cannot create a display connection.") }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            _ = path.withCString { memcpy(bytes.baseAddress!, $0, path.utf8.count) }
        }
        let status = withUnsafePointer(to: &address) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard status == 0 else { Darwin.close(fd); throw RDProblem.message("Waiting for the Android display.") }
        let connection = Connection(fd: fd); connection.timeout(timeout); return connection
    }

    static func tcp(_ port: UInt16, timeout: Int = 20) throws -> Connection {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw RDProblem.message("Cannot create an Android connection.") }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let status = withUnsafePointer(to: &address) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard status == 0 else { Darwin.close(fd); throw RDProblem.message("Android is still starting.") }
        let connection = Connection(fd: fd); connection.timeout(timeout); return connection
    }

    func timeout(_ seconds: Int) {
        var value = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &value, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &value, socklen_t(MemoryLayout<timeval>.size))
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
    }

    func close() {
        closeLock.lock(); defer { closeLock.unlock() }
        if !closed { closed = true; shutdown(fd, SHUT_RDWR); Darwin.close(fd) }
    }

    func send(_ data: Data) throws {
        writeLock.lock(); defer { writeLock.unlock() }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw RDProblem.message("Android stopped accepting input. Reopen the app if it has shut down.") }
                offset += count
            }
        }
    }
    func send(_ text: String) throws { try send(Data(text.utf8)) }

    func read(_ count: Int) throws -> Data {
        guard count >= 0 && count <= 32 * 1024 * 1024 else { throw RDProblem.message("Invalid display packet size.") }
        while buffered.count < count {
            var bytes = [UInt8](repeating: 0, count: min(max(count - buffered.count, 4096), 65536))
            let got = Darwin.read(fd, &bytes, bytes.count)
            if got < 0 && errno == EINTR { continue }
            guard got > 0 else { throw RDProblem.message("The Android connection closed or timed out.") }
            buffered.append(contentsOf: bytes.prefix(got))
        }
        let result = Data(buffered.prefix(count))
        buffered = Data(buffered.dropFirst(count))
        return result
    }

    func line(maximum: Int = 1 << 20) throws -> String {
        var bytes = Data()
        while bytes.count < maximum {
            let b = try read(1)[0]
            if b == 10 { return String(decoding: bytes, as: UTF8.self) }
            bytes.append(b)
        }
        throw RDProblem.message("Android returned an oversized response.")
    }
}

func shellQuote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
func be16(_ n: Int) -> [UInt8] { [UInt8((n >> 8) & 255), UInt8(n & 255)] }
func be32(_ n: Int32) -> [UInt8] {
    let value = UInt32(bitPattern: n)
    return [UInt8((value >> 24) & 255), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)]
}
func u16(_ data: Data, _ offset: Int = 0) -> Int { Int(data[offset]) << 8 | Int(data[offset + 1]) }
func u32(_ data: Data, _ offset: Int = 0) -> Int {
    (Int(data[offset]) << 24) | (Int(data[offset + 1]) << 16) | (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
}
