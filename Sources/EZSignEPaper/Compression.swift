import Foundation

/// Protocol for data compression
public protocol DataCompressor: Sendable {
    /// Compress data using LZO1X-1 algorithm
    /// - Parameter data: Uncompressed data
    /// - Returns: Compressed data
    /// - Throws: EZSignEPaperError if compression fails
    func compress(_ data: Data) throws -> Data
}

/// Default LZO compressor implementation
/// Note: This requires lzo library to be available
/// For production use, link against lzo library or use a Swift wrapper
public final class LZOCompressor: DataCompressor {
    public init() {}
    
    public func compress(_ data: Data) throws -> Data {
        // This is a placeholder implementation
        // In a real implementation, you would call lzo1x_1_compress
        // For now, we'll provide a mock implementation for testing
        
        #if DEBUG
        // In debug mode, return data with a simple run-length encoding simulation
        // This is NOT actual LZO compression, just a placeholder
        return try mockCompress(data)
        #else
        // In production, you would call actual LZO compression
        throw EZSignEPaperError.compressionFailed("LZO compression not implemented. Please provide a proper LZO compressor.")
        #endif
    }
    
    private func mockCompress(_ data: Data) throws -> Data {
        // Simple mock compression for testing
        // Returns the original data prefixed with a simple header
        
        // Check for runs of identical bytes
        var compressed = Data()
        var i = 0
        while i < data.count {
            let byte = data[i]
            var runLength = 1
            
            while i + runLength < data.count && data[i + runLength] == byte && runLength < 255 {
                runLength += 1
            }
            
            if runLength >= 3 {
                // Encode as run: marker (0xFF) + count + byte
                compressed.append(0xFF)
                compressed.append(UInt8(runLength))
                compressed.append(byte)
                i += runLength
            } else {
                // Copy literal bytes
                for j in 0..<runLength {
                    compressed.append(data[i + j])
                }
                i += runLength
            }
        }
        
        return compressed.count < data.count ? compressed : data
    }
}

/// No compression (pass-through) - for testing
public final class NoCompressor: DataCompressor {
    public init() {}
    
    public func compress(_ data: Data) throws -> Data {
        return data
    }
}
