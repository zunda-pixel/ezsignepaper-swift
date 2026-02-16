import Testing
@testable import EZSignEPaper

@Suite("Image Data Processor Tests")
struct ImageDataProcessorTests {
    @Test("Fragmentation with single fragment per block")
    func fragmentationSingleFragment() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: NoCompressor())
        
        let fragments = try processor.processImage(image)
        
        // With no compression, each block is 2000 bytes
        // Each fragment can be max 250 bytes
        // So each block needs 8 fragments (2000 / 250 = 8)
        // 15 blocks * 8 fragments = 120 fragments
        #expect(fragments.count == 120)
        
        // Check first block fragments
        let firstBlockFragments = fragments.filter { $0.blockNo == 0 }
        #expect(firstBlockFragments.count == 8)
        
        // Check that only the last fragment is marked as last
        #expect(firstBlockFragments[0].isLastFragment == false)
        #expect(firstBlockFragments[7].isLastFragment == true)
        
        // Check fragment numbers
        for (index, fragment) in firstBlockFragments.enumerated() {
            #expect(fragment.fragNo == UInt8(index))
        }
    }
    
    @Test("Fragmentation with mock compression")
    func fragmentationWithMockCompression() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: LZOCompressor())
        
        let fragments = try processor.processImage(image)
        
        // With mock compression, blocks should compress well (uniform white)
        // Total number of fragments should be less than uncompressed
        #expect(fragments.count > 0)
        
        // Should have 15 blocks (0-14)
        let blockNumbers = Set(fragments.map { $0.blockNo })
        #expect(blockNumbers.count == 15)
        
        // Each block should have at least one fragment
        for blockNo in 0..<15 {
            let blockFragments = fragments.filter { $0.blockNo == blockNo }
            #expect(blockFragments.count > 0)
            
            // Last fragment should be marked
            #expect(blockFragments.last?.isLastFragment == true)
        }
    }
    
    @Test("Fragments to APDUs conversion")
    func fragmentsToAPDUs() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: NoCompressor())
        
        let fragments = try processor.processImage(image)
        let apdus = processor.fragmentsToAPDUs(fragments)
        
        #expect(apdus.count == fragments.count)
        
        // Check first APDU
        let firstAPDU = apdus[0]
        #expect(firstAPDU.cla == 0xF0)
        #expect(firstAPDU.ins == 0xD3)
        #expect(firstAPDU.p1 == 0x00)
        
        // Check that data contains blockNo and fragNo
        #expect(firstAPDU.data.count >= 2)
    }
}
