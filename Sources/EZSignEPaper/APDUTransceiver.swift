import Foundation

/// Protocol for APDU communication with the e-paper display
public protocol APDUTransceiver {
    /// Send APDU command and receive response
    /// - Parameter apdu: APDU command to send
    /// - Returns: APDU response
    /// - Throws: EZSignEPaperError on communication failure
    func transceive(_ apdu: APDU) async throws -> APDUResponse
}

#if canImport(CoreNFC)
import CoreNFC

/// NFC-based APDU transceiver using CoreNFC
@available(iOS 14.0, *)
public class NFCAPDUTransceiver: APDUTransceiver {
    private let tag: NFCISO7816Tag
    
    public init(tag: NFCISO7816Tag) {
        self.tag = tag
    }
    
    public func transceive(_ apdu: APDU) async throws -> APDUResponse {
        let apduData = apdu.serialize()
        
        // Create NFCISO7816APDU
        guard let nfcAPDU = NFCISO7816APDU(data: apduData) else {
            throw EZSignEPaperError.communicationError("Failed to create NFC APDU")
        }
        
        do {
            let response = try await tag.sendCommand(apdu: nfcAPDU)
            
            // Parse response
            let dataLength = response.count >= 2 ? response.count - 2 : 0
            let responseData = dataLength > 0 ? response.prefix(dataLength) : Data()
            let sw1 = response.count >= 2 ? response[response.count - 2] : 0
            let sw2 = response.count >= 1 ? response[response.count - 1] : 0
            
            return APDUResponse(data: Data(responseData), sw1: sw1, sw2: sw2)
        } catch {
            throw EZSignEPaperError.communicationError("NFC communication failed: \(error.localizedDescription)")
        }
    }
}
#endif

/// Mock APDU transceiver for testing
public class MockAPDUTransceiver: APDUTransceiver {
    public var responses: [APDUResponse] = []
    private var responseIndex = 0
    
    public init() {}
    
    public func transceive(_ apdu: APDU) async throws -> APDUResponse {
        guard responseIndex < responses.count else {
            // Default success response
            return APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00)
        }
        
        let response = responses[responseIndex]
        responseIndex += 1
        return response
    }
    
    public func reset() {
        responseIndex = 0
    }
}
