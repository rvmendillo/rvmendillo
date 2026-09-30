// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

struct FrameBuffer {
    private(set) var width: Int
    private(set) var height: Int
    private(set) var pixels: [UInt8]
    init(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= 2048, height <= 2048 else {
            throw NSError(domain: "ReyDroid", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported Android display size."])
        }
        self.width = width; self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }
    mutating func update(x: Int, y: Int, width w: Int, height h: Int, bytes: Data) throws {
        guard x >= 0, y >= 0, w >= 0, h >= 0, x <= width - w, y <= height - h, bytes.count == w * h * 4 else {
            throw NSError(domain: "ReyDroid", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed Android display rectangle."])
        }
        for row in 0..<h {
            let destination = ((y + row) * width + x) * 4
            let source = row * w * 4
            pixels.replaceSubrange(destination..<destination + w * 4, with: bytes[source..<source + w * 4])
        }
    }
}
