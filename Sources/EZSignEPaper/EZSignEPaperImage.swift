import Foundation
import Algorithms

/// Image representation for EZ Sign EPaper
public struct EZSignEPaperImage: Sendable {
    /// Pixel data as color indices (row-major order: [y][x])
    public let pixels: [[ColorIndex]]
    
    /// Initialize with pixel data
    /// - Parameter pixels: 2D array of color indices [height][width]
    public init(pixels: [[ColorIndex]]) throws {
        guard pixels.count == DisplayConstants.height else {
            throw EZSignEPaperError.invalidImageSize("Height must be \(DisplayConstants.height), got \(pixels.count)")
        }
        
        for row in pixels {
            guard row.count == DisplayConstants.width else {
                throw EZSignEPaperError.invalidImageSize("Width must be \(DisplayConstants.width), got \(row.count)")
            }
        }
        
        self.pixels = pixels
    }
    
    /// Initialize with a single color
    /// - Parameter color: Color to fill the entire display
    public init(fillColor color: ColorIndex) {
        self.pixels = Array(repeating: Array(repeating: color, count: DisplayConstants.width), count: DisplayConstants.height)
    }
    
    /// Pack pixels into bytes (4 pixels per byte)
    /// byte = p0 | (p1 << 2) | (p2 << 4) | (p3 << 6)
    /// Bytes within a row are ordered right to left
    private func packPixels() -> Data {
        var result = Data()
        result.reserveCapacity(DisplayConstants.height * DisplayConstants.bytesPerRow)
        
        for row in pixels {
            var rowData = Data()
            rowData.reserveCapacity(DisplayConstants.bytesPerRow)
            
            // Process pixels in groups of 4 using swift-algorithms
            for chunk in row.chunks(ofCount: 4) {
                let pixelValues = chunk.map { $0.rawValue2Bit }
                let byte = pixelValues[0] 
                    | (pixelValues[1] << 2) 
                    | (pixelValues[2] << 4) 
                    | (pixelValues[3] << 6)
                rowData.append(byte)
            }
            
            // Reverse the bytes (right to left ordering)
            result.append(contentsOf: rowData.reversed())
        }
        
        return result
    }
    
    /// Get uncompressed data blocks
    /// Returns array of 15 blocks, each 2000 bytes
    public func getUncompressedBlocks() -> [Data] {
        let packedData = packPixels()
        var blocks: [Data] = []
        
        for blockNo in 0..<DisplayConstants.blockCount {
            let start = blockNo * DisplayConstants.bytesPerBlock
            let end = start + DisplayConstants.bytesPerBlock
            let blockData = packedData.subdata(in: start..<end)
            blocks.append(blockData)
        }
        
        return blocks
    }
}

/// Errors for EZ Sign EPaper operations
public enum EZSignEPaperError: Error, LocalizedError, Sendable, Equatable {
    case invalidImageSize(String)
    case compressionFailed(String)
    case communicationError(String)
    case authenticationFailed
    case updateTimeout
    case invalidResponse(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImageSize(let msg):
            return "Invalid image size: \(msg)"
        case .compressionFailed(let msg):
            return "Compression failed: \(msg)"
        case .communicationError(let msg):
            return "Communication error: \(msg)"
        case .authenticationFailed:
            return "Authentication failed"
        case .updateTimeout:
            return "Update timeout"
        case .invalidResponse(let msg):
            return "Invalid response: \(msg)"
        }
    }
}
