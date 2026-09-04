import XCTest
@testable import ReyLab

final class ToolTests: XCTestCase {
    func testKnapsackFindsExactCombinationAndNoDuplicates() throws {
        let items = [PackItem(name:"A",value:60,weight:10),PackItem(name:"B",value:100,weight:20),PackItem(name:"C",value:120,weight:30)]
        XCTAssertEqual(try Knapsack.solve(items,capacity:50).map(\.name),["B","C"])
        XCTAssertEqual(try Knapsack.solve([items[0]],capacity:50).count,1)
        XCTAssertTrue(try Knapsack.solve(items,capacity:5).isEmpty)
        XCTAssertThrowsError(try Knapsack.solve(items,capacity:0))
    }
    func testMIDIConvertsNotesPreservesPercussionAndTiming() throws {
        let track: [UInt8] = [0,0x90,60,100,0x60,0x80,60,0,0,0x90,64,100,0x60,0x80,64,0,0,0x90,67,100,0x60,0x80,67,0,0,0x99,36,100,0x60,0x89,36,0,0,0xff,0x2f,0]
        let header: [UInt8] = Array("MThd".utf8)+[0,0,0,6,0,0,0,1,0,96]+Array("MTrk".utf8)+[0,0,0,UInt8(track.count)]
        let source = Data(header+track)
        let result = try MIDIRelative.convert(source,forcedMinor:false)
        XCTAssertEqual(result.sourceKey,"C major"); XCTAssertEqual(result.targetKey,"A minor")
        let output = Array(result.data)
        XCTAssertEqual(output[24],57); XCTAssertEqual(output[32],60); XCTAssertEqual(output[40],64)
        XCTAssertEqual(output[48],36); XCTAssertEqual(output[52],36)
        XCTAssertEqual(output.count,source.count)
        XCTAssertThrowsError(try MIDIRelative.convert(Data([0,1,2])))
    }
    func testSloperProducesFiniteMeasuredPattern() throws {
        let m = SloperMeasurements()
        try m.validate()
        XCTAssertEqual(m.width,50)
        XCTAssertEqual(m.height,61.5)
        XCTAssertTrue(m.lines().flatMap{$0}.allSatisfy{$0.x.isFinite && $0.y.isFinite})
        let pdf = try m.pdf()
        XCTAssertTrue(String(decoding:pdf.prefix(4),as:UTF8.self).hasPrefix("%PDF"))
        var invalid = m; invalid.hip = 30
        XCTAssertThrowsError(try invalid.validate())
    }
    func testServerAddressRejectsInvalidInputs() {
        XCTAssertNil(ServerAddress.base("http://example.com"))
        XCTAssertNil(ServerAddress.base("https://name:password@example.com"))
        XCTAssertNil(ServerAddress.base("https://example.com?secret=x"))
        XCTAssertNotNil(ServerAddress.base("https://example.com/app"))
    }
}
