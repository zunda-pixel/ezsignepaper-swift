import Testing
@testable import EZSignEPaper

@Suite("ColorIndex Tests")
struct ColorIndexTests {
    @Test("Color index values")
    func colorIndexValues() {
        #expect(ColorIndex.black.rawValue == 0)
        #expect(ColorIndex.white.rawValue == 1)
        #expect(ColorIndex.yellow.rawValue == 2)
        #expect(ColorIndex.red.rawValue == 3)
    }
    
    @Test("Color index 2-bit conversion")
    func colorIndex2Bit() {
        #expect(ColorIndex.black.rawValue2Bit == 0b00)
        #expect(ColorIndex.white.rawValue2Bit == 0b01)
        #expect(ColorIndex.yellow.rawValue2Bit == 0b10)
        #expect(ColorIndex.red.rawValue2Bit == 0b11)
    }
}

@Suite("Display Constants Tests")
struct DisplayConstantsTests {
    @Test("Display dimensions")
    func displayDimensions() {
        #expect(DisplayConstants.width == 400)
        #expect(DisplayConstants.height == 300)
    }
    
    @Test("Block calculations")
    func blockCalculations() {
        #expect(DisplayConstants.rowsPerBlock == 20)
        #expect(DisplayConstants.blockCount == 15) // 300 / 20
        #expect(DisplayConstants.bytesPerRow == 100) // 400 / 4
        #expect(DisplayConstants.bytesPerBlock == 2000) // 100 * 20
    }
    
    @Test("Max fragment size")
    func maxFragmentSize() {
        #expect(DisplayConstants.maxFragmentSize == 250) // 0xFC - 2
    }
}
