import Foundation

/// Constants for EZ Sign EPaper display
public enum DisplayConstants {
    /// Display width in pixels
    public static let width: Int = 400
    
    /// Display height in pixels
    public static let height: Int = 300
    
    /// Number of rows per block
    public static let rowsPerBlock: Int = 20
    
    /// Number of blocks (height / rowsPerBlock)
    public static let blockCount: Int = height / rowsPerBlock // 15 blocks
    
    /// Bytes per row (width / 4 pixels per byte)
    public static let bytesPerRow: Int = width / 4 // 100 bytes
    
    /// Uncompressed bytes per block
    public static let bytesPerBlock: Int = bytesPerRow * rowsPerBlock // 2000 bytes
    
    /// Maximum fragment size for compressed data (0xFC - 2)
    public static let maxFragmentSize: Int = 0xFC - 2 // 250 bytes
}
