// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import CryptoKit

final class GuestDownload: NSObject, URLSessionDownloadDelegate {
    static let address = URL(string: "https://github.com/Leviidev/Husk/releases/download/lineage-v2/vda-v12.qcow2")!
    static let digest = "a8dbaecc8fdcd682991b078d6bbb7df6972e459208634fa8dcbad24f17208d6a"
    static let size: Int64 = 2057568256
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    private var task: URLSessionDownloadTask?
    let directory: URL
    var onProgress: ((Double) -> Void)?
    var onStatus: ((String) -> Void)?
    var onComplete: ((Result<Void, Error>) -> Void)?
    private var resumeURL: URL { directory.appendingPathComponent("download.resume") }
    var diskURL: URL { directory.appendingPathComponent("system.qcow2") }
    var stampURL: URL { directory.appendingPathComponent("system.verified") }
    var isReady: Bool {
        FileManager.default.fileExists(atPath: diskURL.path) && (try? String(contentsOf: stampURL, encoding: .utf8)) == Self.digest
    }
    init(directory: URL) { self.directory = directory }
    func start() {
        guard task == nil else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let free = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
            guard free > 8_000_000_000 else { throw RDProblem.message("Free at least 8 GB for Android, its data, and working memory, then retry.") }
            if let data = try? Data(contentsOf: resumeURL) { task = session.downloadTask(withResumeData: data) }
            else { task = session.downloadTask(with: Self.address) }
            onStatus?("Downloading Android · 2.06 GB"); task?.resume()
        } catch { onComplete?(.failure(error)) }
    }
    func pause() {
        task?.cancel(byProducingResumeData: { [weak self] data in
            guard let self else { return }
            if let data { try? data.write(to: self.resumeURL, options: .atomic) }
        })
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onProgress?(min(1, Double(totalBytesWritten) / Double(Self.size)))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                throw RDProblem.message("Android download failed. Check your connection and retry.")
            }
            onStatus?("Verifying Android download…")
            let bytes = try location.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard Int64(bytes) == Self.size else { throw RDProblem.message("The Android download is incomplete. Retry the download.") }
            let handle = try FileHandle(forReadingFrom: location); defer { try? handle.close() }
            var hasher = SHA256()
            while let data = try handle.read(upToCount: 4 << 20), !data.isEmpty { hasher.update(data: data) }
            let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == Self.digest else { throw RDProblem.message("Android verification failed. The downloaded file was not accepted.") }
            if FileManager.default.fileExists(atPath: diskURL.path) { try FileManager.default.removeItem(at: diskURL) }
            try FileManager.default.moveItem(at: location, to: diskURL)
            try Self.digest.write(to: stampURL, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: resumeURL)
            task = nil; onComplete?(.success(()))
        } catch { task = nil; onComplete?(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error as NSError? else { return }
        if let resume = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data { try? resume.write(to: resumeURL, options: .atomic) }
        else if error.code != NSURLErrorCancelled { try? FileManager.default.removeItem(at: resumeURL) }
        self.task = nil
        if error.code == NSURLErrorCancelled { onComplete?(.failure(RDProblem.message("Download paused. Tap Prepare Android to resume."))) }
        else { onComplete?(.failure(error)) }
    }
}
