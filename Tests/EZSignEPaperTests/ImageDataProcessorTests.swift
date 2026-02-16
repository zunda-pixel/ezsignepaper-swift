import XCTest
@testable import EZSignEPaper

final class ImageDataProcessorTests: XCTestCase {
    func testFragmentationSingleFragment() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: NoCompressor())
        
        let fragments = try processor.processImage(image)
        
        // With no compression, each block is 2000 bytes
        // Each fragment can be max 250 bytes
        // So each block needs 8 fragments (2000 / 250 = 8)
        // 15 blocks * 8 fragments = 120 fragments
        XCTAssertEqual(fragments.count, 120)
        
        // Check first block fragments
        let firstBlockFragments = fragments.filter { $0.blockNo == 0 }
        XCTAssertEqual(firstBlockFragments.count, 8)
        
        // Check that only the last fragment is marked as last
        XCTAssertFalse(firstBlockFragments[0].isLastFragment)
        XCTAssertTrue(firstBlockFragments[7].isLastFragment)
        
        // Check fragment numbers
        for (index, fragment) in firstBlockFragments.enumerated() {
            XCTAssertEqual(fragment.fragNo, UInt8(index))
        }
    }
    
    func testFragmentationWithMockCompression() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: LZOCompressor())
        
        let fragments = try processor.processImage(image)
        
        // With mock compression, blocks should compress well (uniform white)
        // Total number of fragments should be less than uncompressed
        XCTAssertGreaterThan(fragments.count, 0)
        
        // Should have 15 blocks (0-14)
        let blockNumbers = Set(fragments.map { $0.blockNo })
        XCTAssertEqual(blockNumbers.count, 15)
        
        // Each block should have at least one fragment
        for blockNo in 0..<15 {
            let blockFragments = fragments.filter { $0.blockNo == blockNo }
            XCTAssertGreaterThan(blockFragments.count, 0)
            
            // Last fragment should be marked
            XCTAssertTrue(blockFragments.last?.isLastFragment ?? false)
        }
    }
    
    func testFragmentsToAPDUs() throws {
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: NoCompressor())
        
        let fragments = try processor.processImage(image)
        let apdus = processor.fragmentsToAPDUs(fragments)
        
        XCTAssertEqual(apdus.count, fragments.count)
        
        // Check first APDU
        let firstAPDU = apdus[0]
        XCTAssertEqual(firstAPDU.cla, 0xF0)
        XCTAssertEqual(firstAPDU.ins, 0xD3)
        XCTAssertEqual(firstAPDU.p1, 0x00)
        
        // Check that data contains blockNo and fragNo
        XCTAssertGreaterThanOrEqual(firstAPDU.data.count, 2)
    }
}
