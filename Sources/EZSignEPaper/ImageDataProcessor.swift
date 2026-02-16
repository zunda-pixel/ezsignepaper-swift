import Foundation

/// Represents a fragment of compressed block data
public struct ImageDataFragment {
    public let blockNo: UInt8
    public let fragNo: UInt8
    public let data: Data
    public let isLastFragment: Bool
    
    public init(blockNo: UInt8, fragNo: UInt8, data: Data, isLastFragment: Bool) {
        self.blockNo = blockNo
        self.fragNo = fragNo
        self.data = data
        self.isLastFragment = isLastFragment
    }
}

/// Process image data into compressed fragments ready for transmission
public class ImageDataProcessor {
    private let compressor: DataCompressor
    
    public init(compressor: DataCompressor = LZOCompressor()) {
        self.compressor = compressor
    }
    
    /// Process an image into compressed fragments
    /// - Parameter image: Image to process
    /// - Returns: Array of fragments ready for transmission
    /// - Throws: EZSignEPaperError if processing fails
    public func processImage(_ image: EZSignEPaperImage) throws -> [ImageDataFragment] {
        let uncompressedBlocks = image.getUncompressedBlocks()
        var fragments: [ImageDataFragment] = []
        
        for (blockNo, blockData) in uncompressedBlocks.enumerated() {
            let compressedBlock = try compressor.compress(blockData)
            let blockFragments = try fragmentBlock(blockNo: UInt8(blockNo), compressedData: compressedBlock)
            fragments.append(contentsOf: blockFragments)
        }
        
        return fragments
    }
    
    /// Fragment a compressed block into multiple fragments if needed
    /// - Parameters:
    ///   - blockNo: Block number (0-14)
    ///   - compressedData: Compressed block data
    /// - Returns: Array of fragments
    /// - Throws: EZSignEPaperError if fragmentation fails
    private func fragmentBlock(blockNo: UInt8, compressedData: Data) throws -> [ImageDataFragment] {
        guard blockNo < DisplayConstants.blockCount else {
            throw EZSignEPaperError.invalidImageSize("Block number \(blockNo) out of range")
        }
        
        var fragments: [ImageDataFragment] = []
        var offset = 0
        var fragNo: UInt8 = 0
        
        while offset < compressedData.count {
            let remainingBytes = compressedData.count - offset
            let fragmentSize = min(remainingBytes, DisplayConstants.maxFragmentSize)
            let fragmentData = compressedData.subdata(in: offset..<(offset + fragmentSize))
            let isLast = (offset + fragmentSize) >= compressedData.count
            
            let fragment = ImageDataFragment(
                blockNo: blockNo,
                fragNo: fragNo,
                data: fragmentData,
                isLastFragment: isLast
            )
            
            fragments.append(fragment)
            offset += fragmentSize
            fragNo += 1
        }
        
        return fragments
    }
    
    /// Convert fragments to APDU commands
    /// - Parameter fragments: Array of image data fragments
    /// - Returns: Array of APDU commands
    public func fragmentsToAPDUs(_ fragments: [ImageDataFragment]) -> [APDU] {
        return fragments.map { fragment in
            EZSignEPaperCommand.imageDataTransfer(
                blockNo: fragment.blockNo,
                fragNo: fragment.fragNo,
                compressedFragment: fragment.data,
                isLastFragment: fragment.isLastFragment
            )
        }
    }
}
