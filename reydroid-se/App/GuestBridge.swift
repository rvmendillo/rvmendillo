// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

struct AndroidApp: Identifiable {
    let package: String
    var id: String { package }
    var name: String { package.split(separator: ".").last.map(String.init) ?? package }
}

// All access is serialized by AppModel.bridgeQueue. The guest's shell service
// is provided by the explicitly pinned Husk Android image, on guest port 5599.
final class GuestBridge {
    private var connection: Connection?
    let port: UInt16
    init(port: UInt16) { self.port = port }
    private func socket() throws -> Connection {
        if let connection { return connection }
        let created = try Connection.tcp(port, timeout: 120)
        connection = created; return created
    }
    func disconnect() { connection?.close(); connection = nil }
    func run(_ command: String, timeout: Int = 120) throws -> String {
        let token = "RD_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        do {
            let c = try socket(); c.timeout(timeout)
            try c.send("{ \(command); } 2>&1; printf '\\n\(token):%s\\n' \"$?\"\n")
            return try collect(c, token: token)
        } catch { disconnect(); throw error }
    }
    private func collect(_ c: Connection, token: String) throws -> String {
        var output = ""
        while output.utf8.count < 4 * 1024 * 1024 {
            let line = try c.line()
            if line.hasPrefix(token + ":") {
                guard line.trimmingCharacters(in: .whitespacesAndNewlines) == token + ":0" else {
                    throw RDProblem.message(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Android rejected the command." : output)
                }
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            output += line + "\n"
        }
        throw RDProblem.message("Android returned too much output.")
    }
    func ready() throws -> Bool { try run("getprop sys.boot_completed", timeout: 8).contains("1") }
    func listApps() throws -> [AndroidApp] {
        try run("pm list packages -3", timeout: 180).split(separator: "\n").compactMap { line in
            guard line.hasPrefix("package:") else { return nil }
            let package = String(line.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !package.isEmpty, package.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._")).contains($0) }) else { return nil }
            return AndroidApp(package: package)
        }.sorted { $0.package < $1.package }
    }
    func install(_ file: URL, progress: @escaping (Double) -> Void) throws {
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let destination = "/data/local/tmp/reydroid-\(id).apk"
        let bytes = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0 else { throw RDProblem.message("This APK is empty.") }
        do {
            let c = try socket(); c.timeout(180)
            let token = "RD_UPLOAD_" + id
            try c.send("printf '\(token)_READY\\n'; head -c \(bytes) > \(shellQuote(destination)); printf '\\n\(token):%s\\n' \"$?\"\n")
            var lines = 0
            while try c.line() != token + "_READY" {
                lines += 1; guard lines < 100 else { throw RDProblem.message("Could not prepare APK transfer.") }
            }
            let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
            var sent = 0
            while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty {
                try c.send(chunk); sent += chunk.count; progress(Double(sent) / Double(bytes))
            }
            guard sent == bytes else { throw RDProblem.message("The APK changed during transfer.") }
            _ = try collect(c, token: token)
            let result = try run("pm install -r \(shellQuote(destination))", timeout: 600)
            _ = try? run("rm -f \(shellQuote(destination))")
            guard result.contains("Success") else { throw RDProblem.message("Android could not install this APK: \(result)") }
        } catch { disconnect(); throw error }
    }
    func launch(_ app: AndroidApp) throws {
        _ = try run("monkey -p \(shellQuote(app.package)) -c android.intent.category.LAUNCHER 1", timeout: 120)
    }
    func key(_ code: Int) throws { _ = try run("input keyevent \(code)") }
    func type(_ text: String) throws { _ = try run("input text \(shellQuote(text.replacingOccurrences(of: " ", with: "%s")))") }
}
