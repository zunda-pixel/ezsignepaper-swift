import Foundation

/// Color index for EZ Sign EPaper display (2-bit color)
public enum ColorIndex: UInt8, Sendable {
    case black = 0
    case white = 1
    case yellow = 2
    case red = 3
    
    /// Convert to raw 2-bit value
    public var rawValue2Bit: UInt8 {
        return rawValue & 0b11
    }
}
