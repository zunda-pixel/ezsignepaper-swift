import Testing
@testable import EZSignEPaper

@Suite("EZSignEPaper Image Tests")
struct EZSignEPaperImageTests {
    @Test("Image initialization with valid dimensions")
    func imageInitialization() throws {
        let pixels = Array(repeating: Array(repeating: ColorIndex.white, count: 400), count: 300)
        let image = try EZSignEPaperImage(pixels: pixels)
        
        #expect(image.pixels.count == 300)
        #expect(image.pixels[0].count == 400)
    }
    
    @Test("Image initialization with invalid height")
    func imageInitializationInvalidHeight() {
        let pixels = Array(repeating: Array(repeating: ColorIndex.white, count: 400), count: 100)
        
        #expect(throws: EZSignEPaperError.self) {
            try EZSignEPaperImage(pixels: pixels)
        }
    }
    
    @Test("Image initialization with invalid width")
    func imageInitializationInvalidWidth() {
        let pixels = Array(repeating: Array(repeating: ColorIndex.white, count: 100), count: 300)
        
        #expect(throws: EZSignEPaperError.self) {
            try EZSignEPaperImage(pixels: pixels)
        }
    }
    
    @Test("Image fill color")
    func imageFillColor() {
        let image = EZSignEPaperImage(fillColor: .red)
        
        #expect(image.pixels.count == 300)
        #expect(image.pixels[0].count == 400)
        #expect(image.pixels[0][0] == .red)
        #expect(image.pixels[299][399] == .red)
    }
    
    @Test("Uncompressed blocks")
    func uncompressedBlocks() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let blocks = image.getUncompressedBlocks()
        
        // Should have 15 blocks
        #expect(blocks.count == 15)
        
        // Each block should be 2000 bytes
        for block in blocks {
            #expect(block.count == 2000)
        }
    }
    
    @Test("Pixel packing")
    func pixelPacking() throws {
        // Create a simple test pattern
        var pixels = Array(repeating: Array(repeating: ColorIndex.black, count: 400), count: 300)
        
        // Set first 4 pixels to different colors
        pixels[0][0] = .black   // 0b00
        pixels[0][1] = .white   // 0b01
        pixels[0][2] = .yellow  // 0b10
        pixels[0][3] = .red     // 0b11
        
        let image = try EZSignEPaperImage(pixels: pixels)
        let blocks = image.getUncompressedBlocks()
        
        // Get the first block
        let firstBlock = blocks[0]
        
        // Due to right-to-left byte ordering, we need to check the last byte of the first row
        // The first row is at offset 0, and its last byte is at index 99 (100th byte)
        // The packed byte should be: p0 | (p1 << 2) | (p2 << 4) | (p3 << 6)
        // = 0b00 | (0b01 << 2) | (0b10 << 4) | (0b11 << 6)
        // = 0b00 | 0b0100 | 0b100000 | 0b11000000
        // = 0b11100100 = 0xE4
        let lastByteOfFirstRow = 99
        let packedByte = firstBlock[lastByteOfFirstRow]
        #expect(packedByte == 0xE4)
    }
}
