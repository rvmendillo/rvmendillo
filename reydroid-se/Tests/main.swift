import Foundation
import Darwin

var frame = try FrameBuffer(width: 4, height: 3)
let rectangle = Data([1,2,3,0,4,5,6,0,7,8,9,0,10,11,12,0])
try frame.update(x: 1, y: 1, width: 2, height: 2, bytes: rectangle)
precondition(Array(frame.pixels[20..<28]) == Array(rectangle[0..<8]))
precondition(Array(frame.pixels[36..<44]) == Array(rectangle[8..<16]))
precondition(frame.pixels[16] == 0 && frame.pixels[28] == 0)
do { try frame.update(x: 3, y: 0, width: 2, height: 1, bytes: Data(repeating: 0, count: 8)); fatalError("out-of-bounds rectangle accepted") } catch {}
do { _ = try FrameBuffer(width: 65535, height: 65535); fatalError("oversized frame accepted") } catch {}
precondition(shellQuote("a'; echo unsafe") == "'a'\\''; echo unsafe'")
precondition(u16(Data(be16(360))) == 360)
precondition(Int32(bitPattern: UInt32(u32(Data(be32(-223))))) == -223)
var sockets = [Int32](repeating: 0, count: 2)
precondition(socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets) == 0)
let first = Connection(fd: sockets[0]), second = Connection(fd: sockets[1])
try first.send(Data([65, 66, 10, 67, 68, 69, 70]))
let line = try second.line(), part1 = try second.read(2), part2 = try second.read(2)
precondition(line == "AB")
precondition(part1 == Data([67,68]))
precondition(part2 == Data([69,70]))
first.close(); second.close()
print("PASS: display bounds, pixel placement, protocol integers, shell escaping, fragmented/buffered socket reads")
