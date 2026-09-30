import AppKit
import Foundation
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(red: 0.055, green: 0.065, blue: 0.105, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
for (offset, opacity) in [(0.0, 1.0), (-95.0, 0.35), (-185.0, 0.16)].reversed() {
    NSColor(red: 0.59, green: 0.49, blue: 1, alpha: opacity).setFill()
    NSBezierPath(roundedRect: NSRect(x: 230, y: 390 + offset, width: 565, height: 370), xRadius: 90, yRadius: 90).fill()
}
let text = "R" as NSString
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 265, weight: .bold), .foregroundColor: NSColor.white]
let size = text.size(withAttributes: attributes)
text.draw(at: NSPoint(x: (1024-size.width)/2, y: 420), withAttributes: attributes)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("Icon.png"))
try """
{"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"ReyDroid","version":1}}
""".write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
