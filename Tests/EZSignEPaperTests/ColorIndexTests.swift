import XCTest
@testable import EZSignEPaper

final class ColorIndexTests: XCTestCase {
    func testColorIndexValues() {
        XCTAssertEqual(ColorIndex.black.rawValue, 0)
        XCTAssertEqual(ColorIndex.white.rawValue, 1)
        XCTAssertEqual(ColorIndex.yellow.rawValue, 2)
        XCTAssertEqual(ColorIndex.red.rawValue, 3)
    }
    
    func testColorIndex2Bit() {
        XCTAssertEqual(ColorIndex.black.rawValue2Bit, 0b00)
        XCTAssertEqual(ColorIndex.white.rawValue2Bit, 0b01)
        XCTAssertEqual(ColorIndex.yellow.rawValue2Bit, 0b10)
        XCTAssertEqual(ColorIndex.red.rawValue2Bit, 0b11)
    }
}

final class DisplayConstantsTests: XCTestCase {
    func testDisplayDimensions() {
        XCTAssertEqual(DisplayConstants.width, 400)
        XCTAssertEqual(DisplayConstants.height, 300)
    }
    
    func testBlockCalculations() {
        XCTAssertEqual(DisplayConstants.rowsPerBlock, 20)
        XCTAssertEqual(DisplayConstants.blockCount, 15) // 300 / 20
        XCTAssertEqual(DisplayConstants.bytesPerRow, 100) // 400 / 4
        XCTAssertEqual(DisplayConstants.bytesPerBlock, 2000) // 100 * 20
    }
    
    func testMaxFragmentSize() {
        XCTAssertEqual(DisplayConstants.maxFragmentSize, 250) // 0xFC - 2
    }
}
