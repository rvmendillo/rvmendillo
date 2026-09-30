// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import UIKit
import SwiftUI

final class AndroidDisplay: ObservableObject {
    @Published private(set) var image: CGImage?
    @Published private(set) var status = "Waiting for the display"
    private var connection: Connection?
    private let stateLock = NSLock()
    private var active = false
    private let input = DispatchQueue(label: "reydroid.touch")
    private var framebuffer: FrameBuffer?

    private var isActive: Bool { stateLock.lock(); defer { stateLock.unlock() }; return active }
    func start() {
        stateLock.lock(); active = true; stateLock.unlock()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            while isActive {
                do {
                    let socket = try Connection.unix("display.sock", timeout: 120)
                    stateLock.lock(); connection = socket; stateLock.unlock()
                    try run(socket)
                } catch {
                    DispatchQueue.main.async { self.status = error.localizedDescription }
                }
                stateLock.lock(); connection?.close(); connection = nil; stateLock.unlock()
                if isActive { Thread.sleep(forTimeInterval: 1) }
            }
        }
    }
    func stop() {
        stateLock.lock(); active = false; connection?.close(); connection = nil; stateLock.unlock()
    }

    private func run(_ socket: Connection) throws {
        let version = String(decoding: try socket.read(12), as: UTF8.self)
        guard version.hasPrefix("RFB 003.") else { throw RDProblem.message("Unexpected display protocol.") }
        try socket.send("RFB 003.008\n")
        let count = Int(try socket.read(1)[0])
        guard count > 0 else { throw RDProblem.message("The private Android display rejected its connection.") }
        let types = try socket.read(count)
        guard types.contains(1) else { throw RDProblem.message("Unexpected authentication on the private display.") }
        try socket.send(Data([1]))
        guard u32(try socket.read(4)) == 0 else { throw RDProblem.message("Display handshake failed.") }
        try socket.send(Data([1]))
        let header = try socket.read(24)
        framebuffer = try FrameBuffer(width: u16(header), height: u16(header, 2))
        let titleSize = u32(header, 20)
        guard titleSize <= 65536 else { throw RDProblem.message("Invalid display title.") }
        _ = try socket.read(titleSize)
        // Little-endian 32-bit RGB, byte layout R G B X.
        try socket.send(Data([0, 0, 0, 0, 32, 24, 0, 1, 0, 255, 0, 255, 0, 255, 0, 8, 16, 0, 0, 0]))
        try socket.send(Data([2, 0, 0, 3] + be32(0) + be32(-223) + be32(-224)))
        DispatchQueue.main.async { self.status = "Display connected" }
        try request(socket, incremental: false)
        while isActive {
            let type = try socket.read(1)[0]
            switch type {
            case 0:
                let h = try socket.read(3); let count = u16(h, 1)
                guard count <= 8192 else { throw RDProblem.message("Too many display rectangles.") }
                rectangles: for _ in 0..<count {
                    let r = try socket.read(12)
                    let x = u16(r), y = u16(r, 2), w = u16(r, 4), h = u16(r, 6)
                    let encoding = Int32(bitPattern: UInt32(u32(r, 8)))
                    if encoding == -224 { break rectangles }
                    if encoding == -223 { framebuffer = try FrameBuffer(width: w, height: h); continue }
                    guard encoding == 0, w <= 2048, h <= 2048 else { throw RDProblem.message("Unsupported display encoding.") }
                    try framebuffer?.update(x: x, y: y, width: w, height: h, bytes: socket.read(w * h * 4))
                }
                publish()
                Thread.sleep(forTimeInterval: 0.10)
                try request(socket, incremental: true)
            case 1:
                let h = try socket.read(5); _ = try socket.read(u16(h, 3) * 6)
            case 2: break
            case 3:
                let h = try socket.read(7); let length = u32(h, 3)
                guard length <= 1 << 20 else { throw RDProblem.message("Display clipboard is too large.") }
                _ = try socket.read(length)
            default: throw RDProblem.message("Unexpected Android display message.")
            }
        }
    }
    private func request(_ socket: Connection, incremental: Bool) throws {
        guard let buffer = framebuffer else { return }
        try socket.send(Data([3, incremental ? 1 : 0, 0, 0, 0, 0] + be16(buffer.width) + be16(buffer.height)))
    }
    private func publish() {
        guard let frame = framebuffer, let provider = CGDataProvider(data: Data(frame.pixels) as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return }
        DispatchQueue.main.async { self.image = image }
    }
    func pointer(x: Int, y: Int, down: Bool) {
        input.async { [self] in
            stateLock.lock(); let socket = connection; stateLock.unlock()
            try? socket?.send(Data([5, down ? 1 : 0] + be16(x) + be16(y)))
        }
    }
}

struct AndroidSurface: UIViewRepresentable {
    @ObservedObject var display: AndroidDisplay
    func makeUIView(context: Context) -> TouchSurface {
        let view = TouchSurface(); view.pointer = display.pointer; return view
    }
    func updateUIView(_ view: TouchSurface, context: Context) { view.image = display.image }
}

final class TouchSurface: UIView {
    var pointer: ((Int, Int, Bool) -> Void)?
    var image: CGImage? { didSet { layer.contents = image } }
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .black; layer.contentsGravity = .resizeAspect
        isMultipleTouchEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func point(_ touches: Set<UITouch>, down: Bool) {
        guard let image, let touch = touches.first else { return }
        let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
        guard scale > 0 else { return }
        let left = (bounds.width - CGFloat(image.width) * scale) / 2
        let top = (bounds.height - CGFloat(image.height) * scale) / 2
        let p = touch.location(in: self)
        let x = min(image.width - 1, max(0, Int((p.x - left) / scale)))
        let y = min(image.height - 1, max(0, Int((p.y - top) / scale)))
        pointer?(x, y, down)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { point(touches, down: true) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { point(touches, down: true) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { point(touches, down: false) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { point(touches, down: false) }
}
