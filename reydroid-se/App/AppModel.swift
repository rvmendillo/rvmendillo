// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct APKFile: Identifiable {
    let url: URL
    let size: Int
    var id: String { url.lastPathComponent }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

final class AppModel: ObservableObject {
    @Published var files: [APKFile] = []
    @Published var apps: [AndroidApp] = []
    @Published var running = false
    @Published var ready = false
    @Published var downloaded = false
    @Published var downloading = false
    @Published var progress = 0.0
    @Published var busy = false
    @Published var status = "Prepare Android to get started"
    @Published var problem: String?
    @Published var showAndroid = false
    @Published var started: Date?
    @Published var usedSession = false
    let display = AndroidDisplay()
    let directory: URL
    let apksDirectory: URL
    let downloader: GuestDownload
    private let bridgeQueue = DispatchQueue(label: "reydroid.android-control", qos: .utility)
    private let port = UInt16.random(in: 40000...55000)
    private lazy var bridge = GuestBridge(port: port)
    private var timer: Timer?
    private var polling = false

    init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Android", isDirectory: true)
        apksDirectory = directory.deletingLastPathComponent().appendingPathComponent("APKs", isDirectory: true)
        downloader = GuestDownload(directory: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: apksDirectory, withIntermediateDirectories: true)
        downloaded = downloader.isReady
        if downloaded { status = "Android is ready to start" }
        downloader.onProgress = { [weak self] value in DispatchQueue.main.async { self?.progress = value } }
        downloader.onStatus = { [weak self] value in DispatchQueue.main.async { self?.status = value } }
        downloader.onComplete = { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }; self.downloading = false
                switch result {
                case .success: self.downloaded = true; self.status = "Android is ready to start"
                case .failure(let error): self.status = "Download stopped"; self.problem = error.localizedDescription
                }
                UIApplication.shared.isIdleTimerDisabled = self.running
            }
        }
        loadFiles()
    }
    func prepare() {
        guard !downloading else { return }
        downloading = true; progress = 0; UIApplication.shared.isIdleTimerDisabled = true
        downloader.start()
    }
    func loadFiles() {
        let paths = (try? FileManager.default.contentsOfDirectory(at: apksDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        files = paths.filter { $0.pathExtension.lowercased() == "apk" }.map { APKFile(url: $0, size: (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    func importFiles(_ urls: [URL]) {
        guard !busy else { return }; busy = true; status = "Importing APK…"
        let destinationDirectory = apksDirectory
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var errors: [String] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    guard url.pathExtension.lowercased() == "apk" else { throw RDProblem.message("Choose an .apk file. Split APK bundles (.xapk/.apks) are not supported yet.") }
                    let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                    guard let header = try handle.read(upToCount: 4), header == Data([0x50, 0x4b, 0x03, 0x04]) else { throw RDProblem.message("\(url.lastPathComponent) is not an APK/ZIP archive.") }
                    let count = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard count > 0, count <= 2_147_483_648 else { throw RDProblem.message("Use an APK under 2 GB.") }
                    var target = destinationDirectory.appendingPathComponent(url.lastPathComponent)
                    if target.standardizedFileURL == url.standardizedFileURL { continue }
                    if FileManager.default.fileExists(atPath: target.path) { target = destinationDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-" + String(UUID().uuidString.prefix(6)) + ".apk") }
                    try FileManager.default.copyItem(at: url, to: target)
                } catch { errors.append(error.localizedDescription) }
            }
            DispatchQueue.main.async {
                self?.busy = false; self?.loadFiles(); self?.status = "APK import complete"
                if !errors.isEmpty { self?.problem = errors.joined(separator: "\n") }
            }
        }
    }
    func remove(_ file: APKFile) { do { try FileManager.default.removeItem(at: file.url); loadFiles() } catch { problem = error.localizedDescription } }

    func start() {
        guard downloaded, !running, !usedSession else { return }
        do {
            let resource = Bundle.main.resourceURL!
            for (source, target) in [("userdata-seed.qcow2", "userdata.qcow2"), ("efi-vars-seed.fd", "efi-vars.fd")] {
                let destination = directory.appendingPathComponent(target)
                if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.copyItem(at: resource.appendingPathComponent(source), to: destination) }
            }
            for socket in ["display.sock", "control.sock"] { try? FileManager.default.removeItem(at: directory.appendingPathComponent(socket)) }
            let ram = directory.appendingPathComponent("memory.bin")
            if !FileManager.default.fileExists(atPath: ram.path) { FileManager.default.createFile(atPath: ram.path, contents: nil) }
            let file = try FileHandle(forWritingTo: ram); try file.truncate(atOffset: 2048 * 1024 * 1024); try file.close()
            var exclusion = URLResourceValues(); exclusion.isExcludedFromBackup = true
            var mutableDir = directory; try? mutableDir.setResourceValues(exclusion)
            let bios = resource.appendingPathComponent("qemu").path
            let args = [
                "qemu-system-aarch64", "-M", "virt,highmem=on,memory-backend=androidram",
                "-cpu", "max,sve=off,sme=off,pauth-impdef=on", "-smp", "2", "-m", "2048",
                "-accel", "tcg,thread=single,tb-size=64", "-L", bios,
                "-object", "memory-backend-file,id=androidram,size=2048M,mem-path=memory.bin,share=on,prealloc=off",
                "-drive", "if=pflash,unit=0,format=raw,readonly=on,file=\(bios)/edk2-aarch64-code.fd",
                "-drive", "if=pflash,unit=1,format=qcow2,file=efi-vars.fd",
                "-device", "virtio-blk-pci,drive=vda,bootindex=0",
                "-device", "virtio-blk-pci,drive=vdb,bootindex=1",
                "-drive", "file=system.qcow2,if=none,id=vda,format=qcow2,cache=writethrough,discard=unmap",
                "-drive", "file=userdata.qcow2,if=none,id=vdb,format=qcow2,cache=writethrough,discard=unmap",
                "-device", "virtio-net-pci,netdev=net0,romfile=",
                "-netdev", "user,id=net0,hostfwd=tcp:127.0.0.1:\(port)-:5599",
                "-device", "virtio-gpu-pci,xres=360,yres=640",
                "-device", "qemu-xhci,id=usb", "-device", "usb-tablet,bus=usb.0", "-device", "usb-kbd,bus=usb.0",
                "-device", "virtio-rng-pci", "-display", "none", "-vnc", "unix:display.sock",
                "-qmp", "unix:control.sock,server=on,wait=off", "-monitor", "none",
                "-chardev", "file,id=serial,path=android-boot.log", "-serial", "chardev:serial"
            ]
            let library = Bundle.main.privateFrameworksURL!.appendingPathComponent("qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu").path
            running = true; usedSession = true; started = Date(); showAndroid = true
            status = "Starting Android with the interpreter…"; UIApplication.shared.isIdleTimerDisabled = true
            let folder = directory.path; let log = directory.appendingPathComponent("runtime.log").path
            Thread.detachNewThread { [weak self] in
                let strings = args.map { strdup($0)! }; defer { strings.forEach { free($0) } }
                var pointers: [UnsafePointer<CChar>?] = strings.map { UnsafePointer($0) }; pointers.append(nil)
                let result = pointers.withUnsafeMutableBufferPointer { buffer in rd_vm_run(library, folder, log, Int32(args.count), buffer.baseAddress!) }
                let detail = String(cString: rd_vm_error())
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.running = false; self.ready = false; self.timer?.invalidate(); self.display.stop()
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.status = "Android stopped. Close and reopen ReyDroid SE to start another session."
                    if result != 0 { self.problem = detail.isEmpty ? "The interpreter stopped with code \(result). View the runtime log for details." : detail }
                }
            }
            display.start()
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.poll() }
        } catch { problem = error.localizedDescription }
    }
    private func poll() {
        guard running, !ready, !polling, !busy else { return }; polling = true
        bridgeQueue.async { [weak self] in
            guard let self else { return }
            let booted = (try? self.bridge.ready()) == true
            let apps = booted ? (try? self.bridge.listApps()) ?? [] : []
            DispatchQueue.main.async {
                self.polling = false
                if booted { self.ready = true; self.apps = apps; self.status = "Android is ready · no JIT" }
            }
        }
    }
    func refresh() { perform("Refreshing apps…") { [self] in let apps = try bridge.listApps(); DispatchQueue.main.async { self.apps = apps } } }
    func install(_ file: APKFile) {
        perform("Transferring \(file.name)…") { [self] in
            try bridge.install(file.url) { p in DispatchQueue.main.async { self.status = p < 1 ? "Transferring APK · \(Int(p * 100))%" : "Installing APK in Android…" } }
            let list = try bridge.listApps()
            DispatchQueue.main.async { self.apps = list }
        }
    }
    func launch(_ app: AndroidApp) { showAndroid = true; perform("Opening \(app.name)…") { [self] in try bridge.launch(app) } }
    func key(_ code: Int) { perform("Sending input…") { [self] in try bridge.key(code) } }
    func type(_ text: String) { perform("Sending text…") { [self] in try bridge.type(text) } }
    private func perform(_ message: String, work: @escaping () throws -> Void) {
        guard ready, !busy else { return }; busy = true; status = message
        bridgeQueue.async { [weak self] in
            do { try work(); DispatchQueue.main.async { self?.busy = false; self?.status = "Android is ready · no JIT" } }
            catch { DispatchQueue.main.async { self?.busy = false; self?.problem = error.localizedDescription; self?.status = "Android command failed" } }
        }
    }
    func shutdown() {
        status = "Stopping Android…"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let c = try Connection.unix("control.sock"); defer { c.close() }
                _ = try c.line(); try c.send("{\"execute\":\"qmp_capabilities\"}\n")
                _ = try c.line(); try c.send("{\"execute\":\"quit\"}\n")
            } catch { DispatchQueue.main.async { self?.problem = error.localizedDescription } }
        }
    }
    func logText() -> String {
        ["runtime.log", "android-boot.log"].map { name in
            let url = directory.appendingPathComponent(name)
            guard let file = try? FileHandle(forReadingFrom: url) else { return "\(name): no output yet." }
            defer { try? file.close() }
            let size = (try? file.seekToEnd()) ?? 0
            try? file.seek(toOffset: size > 20000 ? size - 20000 : 0)
            return "\(name)\n" + String(decoding: (try? file.readToEnd()) ?? Data(), as: UTF8.self)
        }.joined(separator: "\n\n")
    }
}
