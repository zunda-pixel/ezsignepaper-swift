import Foundation

/// APDU command for ISO7816 communication
public struct APDU: Sendable {
    public let cla: UInt8
    public let ins: UInt8
    public let p1: UInt8
    public let p2: UInt8
    public let data: Data
    
    public init(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: Data = Data()) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
    }
    
    /// Serialize APDU to Data
    public func serialize() -> Data {
        var result = Data()
        result.append(cla)
        result.append(ins)
        result.append(p1)
        result.append(p2)
        
        if !data.isEmpty {
            result.append(UInt8(data.count))
            result.append(data)
        }
        
        return result
    }
}

/// APDU response
public struct APDUResponse: Sendable {
    public let data: Data
    public let sw1: UInt8
    public let sw2: UInt8
    
    public init(data: Data, sw1: UInt8, sw2: UInt8) {
        self.data = data
        self.sw1 = sw1
        self.sw2 = sw2
    }
    
    /// Check if response is success (9000)
    public var isSuccess: Bool {
        return sw1 == 0x90 && sw2 == 0x00
    }
    
    /// Get status word
    public var statusWord: UInt16 {
        return (UInt16(sw1) << 8) | UInt16(sw2)
    }
}

/// APDU command factory for EZ Sign EPaper
public enum EZSignEPaperCommand: Sendable {
    /// Authentication command: 0020 00010420091210
    public static func authenticate() -> APDU {
        let data = Data([0x04, 0x20, 0x09, 0x12, 0x10])
        return APDU(cla: 0x00, ins: 0x20, p1: 0x00, p2: 0x01, data: data)
    }
    
    /// Image data transfer: F0D3 ...
    /// - Parameters:
    ///   - blockNo: Block number (0-14)
    ///   - fragNo: Fragment number
    ///   - compressedFragment: Compressed image data fragment
    ///   - isLastFragment: Whether this is the last fragment of the block
    public static func imageDataTransfer(blockNo: UInt8, fragNo: UInt8, compressedFragment: Data, isLastFragment: Bool) -> APDU {
        var data = Data()
        data.append(blockNo)
        data.append(fragNo)
        data.append(compressedFragment)
        
        return APDU(cla: 0xF0, ins: 0xD3, p1: 0x00, p2: isLastFragment ? 0x01 : 0x00, data: data)
    }
    
    /// Start screen update: F0D4 858000
    public static func startUpdate() -> APDU {
        let data = Data([0x85, 0x80, 0x00])
        return APDU(cla: 0xF0, ins: 0xD4, p1: 0x00, p2: 0x00, data: data)
    }
    
    /// Poll update completion: F0DE 000001
    public static func pollUpdateStatus() -> APDU {
        let data = Data([0x00, 0x00, 0x01])
        return APDU(cla: 0xF0, ins: 0xDE, p1: 0x00, p2: 0x00, data: data)
    }
    
    /// Get screen type (optional): F0D8 000005000000000E
    public static func getScreenType() -> APDU {
        let data = Data([0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x0E])
        return APDU(cla: 0xF0, ins: 0xD8, p1: 0x00, p2: 0x00, data: data)
    }
    
    /// Get device info (optional): 00D1 000000
    public static func getDeviceInfo() -> APDU {
        return APDU(cla: 0x00, ins: 0xD1, p1: 0x00, p2: 0x00, data: Data())
    }
}
