import UIKit
import AVFoundation
import CoreText

struct ASCIISettings: Sendable {
    var columns = 100
    var charset = "#Wo- "
    var darkBackground = true
    var color = true
    var withAudio = true
}

enum ConversionError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct ASCIIFrame {
    let image: CGImage
    let text: String
}

enum ASCIIEngine {
    static func render(_ source: CGImage, settings: ASCIISettings) throws -> ASCIIFrame {
        let columns = min(200, max(20, settings.columns))
        let rows = max(1, min(1000, Int(Double(columns) * Double(source.height) / Double(source.width) * 0.7)))
        let chars = Array(settings.charset.isEmpty ? "#Wo- " : settings.charset).prefix(100).map(String.init)
        let ramp = settings.darkBackground ? Array(chars.reversed()) : Array(chars)
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: columns * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(source, in: CGRect(x: 0, y: 0, width: columns, height: rows))
            return true
        }
        guard ok else { throw ConversionError.message("Could not read the image.") }
        let width = columns * 7 + (columns * 7) % 2
        let height = rows * 10
        guard let canvas = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ConversionError.message("Could not create the ASCII canvas.") }
        canvas.setFillColor((settings.darkBackground ? UIColor.black : UIColor.white).cgColor)
        canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Menlo-Regular" as CFString, 10, nil)
        let glyphs: [CGGlyph] = ramp.map { char in
            var code = Array(char.utf16).first ?? 32
            var glyph: CGGlyph = 0
            CTFontGetGlyphsForCharacters(font, &code, &glyph, 1)
            return glyph
        }
        var lines: [String] = []
        for y in 0..<rows {
            var line = ""
            for x in 0..<columns {
                let i = (y * columns + x) * 4
                let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
                // Match the original colored renderer's average-brightness mapping.
                let brightness = settings.color ? (r + g + b) / 3 : (299 * r + 587 * g + 114 * b) / 1000
                let index = min(ramp.count - 1, brightness * ramp.count / 256)
                line += ramp[index]
                let ink = settings.color ? UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1) : (settings.darkBackground ? UIColor.white : UIColor.black)
                canvas.setFillColor(ink.cgColor)
                var glyph = glyphs[index]
                var point = CGPoint(x: x * 7, y: height - (y + 1) * 10 + 2)
                CTFontDrawGlyphs(font, &glyph, &point, 1, canvas)
            }
            lines.append(line)
        }
        guard let image = canvas.makeImage() else { throw ConversionError.message("Could not finish the image.") }
        return ASCIIFrame(image: image, text: lines.joined(separator: "\n"))
    }

    static func preview(url: URL, settings: ASCIISettings) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1000, height: 1000)
        let source = try generator.copyCGImage(at: .zero, actualTime: nil)
        return try render(source, settings: settings).image
    }

    static func convert(url: URL, settings: ASCIISettings, destination: URL,
                        progress: @escaping @Sendable (Double) -> Void) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ConversionError.message("This file has no readable video track.") }
        let duration = try await asset.load(.duration)
        let transform = try await track.load(.preferredTransform)
        guard duration.seconds.isFinite, duration.seconds > 0 else { throw ConversionError.message("The video duration is invalid.") }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ConversionError.message("Unsupported video format.") }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ConversionError.message("Cannot open video.") }
        let silentURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        var writer: AVAssetWriter?
        var input: AVAssetWriterInput?
        var adaptor: AVAssetWriterInputPixelBufferAdaptor?
        var firstTime: CMTime?
        var frames = 0
        let ci = CIContext(options: [.cacheIntermediates: false])
        defer {
            reader.cancelReading()
            if writer?.status == .writing { writer?.cancelWriting() }
            try? FileManager.default.removeItem(at: silentURL)
        }
        do {
            while let sample = output.copyNextSampleBuffer() {
                try Task.checkCancellation()
                guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
                let time = CMSampleBufferGetPresentationTimeStamp(sample)
                if firstTime == nil { firstTime = time }
                let result: ASCIIFrame = try autoreleasepool {
                    let transformed = CIImage(cvPixelBuffer: buffer).transformed(by: transform)
                    guard let cg = ci.createCGImage(transformed, from: transformed.extent) else { throw ConversionError.message("Cannot decode video frame.") }
                    return try render(cg, settings: settings)
                }
                if writer == nil {
                    let w = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
                    let i = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: result.image.width, AVVideoHeightKey: result.image.height])
                    i.expectsMediaDataInRealTime = false
                    let a = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: i, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: result.image.width, kCVPixelBufferHeightKey as String: result.image.height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
                    guard w.canAdd(i) else { throw ConversionError.message("Video dimensions cannot be encoded.") }
                    w.add(i)
                    guard w.startWriting() else { throw w.error ?? ConversionError.message("Cannot start MP4 export.") }
                    w.startSession(atSourceTime: .zero)
                    writer = w; input = i; adaptor = a
                }
                guard let w = writer, let i = input, let a = adaptor, let pool = a.pixelBufferPool else { throw ConversionError.message("MP4 encoder unavailable.") }
                while !i.isReadyForMoreMediaData {
                    try Task.checkCancellation()
                    guard w.status == .writing else { throw w.error ?? ConversionError.message("MP4 encoder stopped.") }
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                var target: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &target) == kCVReturnSuccess, let target = target else { throw ConversionError.message("Insufficient memory to encode this frame.") }
                CVPixelBufferLockBaseAddress(target, [])
                let context = CGContext(data: CVPixelBufferGetBaseAddress(target), width: result.image.width, height: result.image.height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(target), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
                context?.draw(result.image, in: CGRect(x: 0, y: 0, width: result.image.width, height: result.image.height))
                CVPixelBufferUnlockBaseAddress(target, [])
                guard context != nil, a.append(target, withPresentationTime: CMTimeSubtract(time, firstTime!)) else { throw w.error ?? ConversionError.message("Could not append video frame.") }
                frames += 1
                if frames % 5 == 0 { progress(min(0.94, time.seconds / duration.seconds * 0.94)) }
            }
            guard reader.status == .completed else { throw reader.error ?? ConversionError.message("Video decoding did not complete.") }
            guard let w = writer, let i = input, frames > 0 else { throw ConversionError.message("No video frames were decoded.") }
            i.markAsFinished()
            await withCheckedContinuation { continuation in w.finishWriting { continuation.resume() } }
            guard w.status == .completed else { throw w.error ?? ConversionError.message("MP4 export failed.") }
            try Task.checkCancellation()
            let audioTracks = settings.withAudio ? try await asset.loadTracks(withMediaType: .audio) : []
            if let audio = audioTracks.first {
                progress(0.96)
                let silent = AVURLAsset(url: silentURL)
                let composition = AVMutableComposition()
                guard let video = try await silent.loadTracks(withMediaType: .video).first,
                      let v = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let a = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw ConversionError.message("Cannot combine audio and video.") }
                let length = try await silent.load(.duration)
                try v.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: video, at: .zero)
                let audioRange = try await audio.load(.timeRange)
                let requested = CMTimeRange(start: firstTime ?? .zero, duration: length)
                let range = CMTimeRangeGetIntersection(audioRange, otherRange: requested)
                if range.duration.seconds > 0 {
                    try a.insertTimeRange(range, of: audio, at: CMTimeSubtract(range.start, firstTime ?? .zero))
                }
                guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw ConversionError.message("Audio export unavailable.") }
                exporter.outputURL = destination; exporter.outputFileType = .mp4
                await withTaskCancellationHandler(operation: {
                    await withCheckedContinuation { continuation in exporter.exportAsynchronously { continuation.resume() } }
                }, onCancel: { exporter.cancelExport() })
                try Task.checkCancellation()
                guard exporter.status == .completed else { throw exporter.error ?? ConversionError.message("Audio export failed.") }
            } else {
                try FileManager.default.copyItem(at: silentURL, to: destination)
            }
            progress(1)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
