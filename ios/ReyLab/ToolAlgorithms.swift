import Foundation
import UIKit

struct PackItem: Identifiable {
    var id = UUID()
    var name: String
    var value: Int
    var weight: Int
}

enum Knapsack {
    static func solve(_ items: [PackItem], capacity: Int) throws -> [PackItem] {
        guard (1...10_000).contains(capacity), items.count <= 100,
              items.allSatisfy({ $0.weight > 0 && $0.value >= 0 && $0.value <= 1_000_000 }) else { throw ConversionError.message("Use capacity 1–10,000, positive weights, and values 0–1,000,000.") }
        var scores = [Int](repeating: 0, count: capacity + 1)
        var selections = [[Int]](repeating: [], count: capacity + 1)
        for (index, item) in items.enumerated() where item.weight <= capacity {
            for weight in stride(from: capacity, through: item.weight, by: -1) {
                let candidate = scores[weight - item.weight] + item.value
                if candidate > scores[weight] {
                    scores[weight] = candidate
                    selections[weight] = selections[weight - item.weight] + [index]
                }
            }
        }
        return selections[capacity].map { items[$0] }
    }
}

struct MIDIResult {
    let data: Data
    let sourceKey: String
    let targetKey: String
    let noteCount: Int
}

enum MIDIRelative {
    struct Event { var position: Int; var note: Int; var tick: Int; var on: Bool; var channel: Int }
    static func convert(_ data: Data, forcedMinor: Bool? = nil) throws -> MIDIResult {
        var bytes = Array(data)
        func invalid() -> ConversionError { .message("Unsupported or malformed MIDI. Import a standard format 0 or 1 .mid file.") }
        guard bytes.count >= 14, Array(bytes[0..<4]) == Array("MThd".utf8) else { throw invalid() }
        func word(_ i: Int) -> Int { Int(bytes[i]) * 256 + Int(bytes[i + 1]) }
        func long(_ i: Int) -> Int { word(i) * 65536 + word(i + 2) }
        let header = long(4), format = word(8), tracks = word(10)
        guard header >= 6, header <= bytes.count - 8, format <= 1, tracks > 0, bytes[12] < 128 else { throw invalid() }
        var cursor = 8 + header
        var events: [Event] = []
        var histogram = [Double](repeating: 0, count: 12)
        var keyFlags: [Int] = []
        for _ in 0..<tracks {
            guard cursor + 8 <= bytes.count, Array(bytes[cursor..<(cursor + 4)]) == Array("MTrk".utf8) else { throw invalid() }
            let length = long(cursor + 4)
            cursor += 8
            guard length <= bytes.count - cursor else { throw invalid() }
            let end = cursor + length
            var running: UInt8 = 0
            var tick = 0
            var active: [Int: [Int]] = [:]
            func vlq() throws -> Int {
                var result = 0
                for _ in 0..<4 {
                    guard cursor < end else { throw invalid() }
                    let byte = bytes[cursor]; cursor += 1
                    result = (result << 7) | Int(byte & 127)
                    if byte < 128 { return result }
                }
                throw invalid()
            }
            while cursor < end {
                tick += try vlq()
                guard cursor < end else { throw invalid() }
                var status = bytes[cursor]
                if status >= 128 { cursor += 1; if status < 240 { running = status } }
                else { guard running >= 128 else { throw invalid() }; status = running }
                if status == 255 {
                    running = 0
                    guard cursor < end else { throw invalid() }
                    let type = bytes[cursor]; cursor += 1
                    let count = try vlq()
                    guard count <= end - cursor else { throw invalid() }
                    if type == 89 && count == 2 { keyFlags.append(cursor + 1) }
                    cursor += count
                } else if status == 240 || status == 247 {
                    running = 0
                    let count = try vlq(); guard count <= end - cursor else { throw invalid() }; cursor += count
                } else if status < 240 {
                    let kind = status >> 4, channel = Int(status & 15)
                    let count = (kind == 12 || kind == 13) ? 1 : 2
                    guard cursor + count <= end, bytes[cursor..<(cursor + count)].allSatisfy({ $0 < 128 }) else { throw invalid() }
                    if (kind == 8 || kind == 9) && channel != 9 {
                        let note = Int(bytes[cursor]), on = kind == 9 && bytes[cursor + 1] > 0
                        events.append(Event(position: cursor, note: note, tick: tick, on: on, channel: channel))
                        let key = channel * 128 + note
                        if on { active[key, default: []].append(tick) }
                        else if var starts = active[key], !starts.isEmpty {
                            let start = starts.removeFirst(); active[key] = starts
                            histogram[note % 12] += Double(max(1, tick - start))
                        }
                    }
                    cursor += count
                } else { throw invalid() }
            }
            for (key, starts) in active { for start in starts { histogram[(key % 128) % 12] += Double(max(1, tick - start)) } }
        }
        guard events.contains(where: { $0.on }) else { throw ConversionError.message("This MIDI has no pitched notes to convert.") }
        let major = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
        let minor = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]
        func correlation(_ profile: [Double], root: Int) -> Double {
            let a = histogram.reduce(0,+) / 12, b = profile.reduce(0,+) / 12
            var numerator = 0.0, left = 0.0, right = 0.0
            for i in 0..<12 {
                let x = histogram[i] - a, y = profile[(i - root + 12) % 12] - b
                numerator += x * y; left += x * x; right += y * y
            }
            return numerator / max(0.000001, sqrt(left * right))
        }
        var best = -Double.infinity, tonic = 0, isMinor = false
        for mode in [false, true] where forcedMinor == nil || forcedMinor == mode {
            for root in 0..<12 {
                let score = correlation(mode ? minor : major, root: root)
                if score > best { best = score; tonic = root; isMinor = mode }
            }
        }
        // Rotate two diatonic degrees within the shared major/relative-minor pitch collection.
        // This changes the mode, unlike a uniform three-semitone pitch shift.
        let majorRoot = isMinor ? (tonic + 3) % 12 : tonic
        let scale = [0,2,4,5,7,9,11]
        let candidates = (-3...21).flatMap { octave in scale.enumerated().map { (degree: octave * 7 + $0.offset, pitch: majorRoot + octave * 12 + $0.element) } }
        func floorDiv(_ value: Int, _ divisor: Int) -> Int { Int(floor(Double(value) / Double(divisor))) }
        func moved(_ note: Int) -> Int {
            let match = candidates.min { abs($0.pitch - note) < abs($1.pitch - note) }!
            let degree = match.degree + (isMinor ? 2 : -2)
            let octave = floorDiv(degree, 7), index = degree - octave * 7
            return majorRoot + octave * 12 + scale[index] + note - match.pitch
        }
        for event in events {
            let note = moved(event.note)
            guard (0...127).contains(note) else { throw ConversionError.message("Conversion would move notes outside MIDI's pitch range.") }
            bytes[event.position] = UInt8(note)
        }
        for position in keyFlags { bytes[position] = isMinor ? 0 : 1 }
        let names = ["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"]
        let target = (tonic + (isMinor ? 3 : 9)) % 12
        return MIDIResult(data: Data(bytes), sourceKey: "\(names[tonic]) \(isMinor ? "minor" : "major")", targetKey: "\(names[target]) \(isMinor ? "major" : "minor")", noteCount: events.filter { $0.on }.count)
    }
}

struct SloperMeasurements {
    var waist = 72.0, waistEase = 2.0, hip = 96.0, hipHeight = 20.0, hipEase = 4.0, length = 60.0, backDart = 3.0, frontDart = 2.0
    var width: Double { (hip + hipEase) / 2 }
    var height: Double { length + 1.5 }
    func validate() throws {
        let values = [waist, waistEase, hip, hipHeight, hipEase, length, backDart, frontDart]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 300 }), waist > 0, hip > 0,
              hip + hipEase > waist + waistEase, hipHeight > 0, length > hipHeight,
              backDart + frontDart < (hip + hipEase - waist - waistEase) / 2 else { throw ConversionError.message("Check the measurements: hip plus ease must exceed waist plus ease, darts must fit that difference, and length must exceed hip height.") }
    }
    func lines() -> [[CGPoint]] {
        let hb = hip / 4 - 0.5 + hipEase / 4, total = width, twelfth = hip / 12
        let side = ((hip + hipEase) / 2 - (waist + waistEase) / 2 - frontDart - backDart) / 2
        let bd = hipHeight * 0.75, fd = hipHeight * 0.5
        let bx = (twelfth * 2 + backDart) / 2, fx = total - twelfth - frontDart / 2
        var result: [[CGPoint]] = []
        func line(_ x: Double,_ y: Double,_ a: Double,_ b: Double) { result.append([CGPoint(x:x,y:-y),CGPoint(x:a,y:-b)]) }
        func curve(_ x: Double,_ y: Double,_ u: Double,_ v: Double,_ rotate: Bool = false) {
            let base = cosh(x / 2.54), delta = cosh(u / 2.54) - base
            guard abs(delta) > 1e-10 else { line(x,y,u,v); return }
            let ys = (0..<100).map { i -> Double in
                let xx = x + (u - x) * Double(i) / 99
                return y + (v - y) * (cosh(xx / 2.54) - base) / delta
            }
            result.append((0..<100).map { i in
                let t = Double(i) / 99, middle = y + (v-y)*t
                let yy = rotate ? middle + (y + (v-y)*(1-t) - ys[99-i]) : ys[i]
                return CGPoint(x:x+(u-x)*t,y:-yy)
            })
        }
        line(0,-1.5,0,-height); line(0,-1.5,hb,-1.5)
        line(0,-(1.5+hipHeight),total,-(1.5+hipHeight)); line(0,-height,total,-height)
        line(hb,-(1.5+hipHeight),hb,0); line(hb,-(1.5+hipHeight),hb,-height)
        line(hb-side,0,total,0); line(bx,-1.5,bx,-(1.5+hipHeight))
        curve(twelfth/2,-1.5,hb-side,0)
        line(bx,-(1.5+bd),twelfth,-1.5); line(bx,-(1.5+bd),twelfth+backDart,-1.5)
        line(total,-height,total,-0.7); line(total,-0.7,hb,-0.7)
        line(total,-0.7,total-twelfth,-0.7); line(total-twelfth,-0.7,total-twelfth-frontDart,-0.7)
        line(fx,-0.7,fx,-(1.5+hipHeight)); curve(total-twelfth/2,-0.7,hb+side,0,true)
        line(fx,-(1.5+fd),total-twelfth,-0.7); line(fx,-(1.5+fd),total-twelfth-frontDart,-0.7)
        curve(hb,-(1.5+bd),hb-side,0); curve(hb,-(1.5+bd),hb+side,0,true)
        return result
    }
    func pdf() throws -> Data {
        try validate()
        let cm = 72.0 / 2.54, margin = 28.0
        let bounds = CGRect(x:0,y:0,width:width*cm+margin*2,height:height*cm+margin*2+32)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { renderer in
            renderer.beginPage()
            let c = renderer.cgContext
            ("Rey Lab · Skirt sloper · centimeters · Print at 100%" as NSString).draw(at:CGPoint(x:margin,y:12),withAttributes:[.font:UIFont.systemFont(ofSize:10)])
            c.translateBy(x:margin,y:margin+24); c.scaleBy(x:cm,y:cm)
            c.setStrokeColor(UIColor.lightGray.cgColor); c.setLineWidth(0.01)
            for x in stride(from:0.0,through:width,by:1) { c.move(to:CGPoint(x:x,y:0)); c.addLine(to:CGPoint(x:x,y:height)) }
            for y in stride(from:0.0,through:height,by:1) { c.move(to:CGPoint(x:0,y:y)); c.addLine(to:CGPoint(x:width,y:y)) }; c.strokePath()
            c.setStrokeColor(UIColor.black.cgColor); c.setLineWidth(0.04)
            for points in lines() { c.addLines(between:points); c.strokePath() }
        }
    }
}
