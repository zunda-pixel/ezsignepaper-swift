import XCTest
@testable import EZSignEPaper

final class EZSignEPaperControllerTests: XCTestCase {
    func testAuthenticateSuccess() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        try await controller.authenticate()
        
        // Should complete without error
    }
    
    func testAuthenticateFailure() async {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data(), sw1: 0x67, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        
        do {
            try await controller.authenticate()
            XCTFail("Should have thrown authentication error")
        } catch EZSignEPaperError.authenticationFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testStartUpdate() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        try await controller.startUpdate()
    }
    
    func testPollUpdateStatusUpdating() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data([0x01]), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        let status = try await controller.pollUpdateStatus()
        
        if case .updating = status {
            // Expected
        } else {
            XCTFail("Expected updating status")
        }
    }
    
    func testPollUpdateStatusCompleted() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data([0x00]), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        let status = try await controller.pollUpdateStatus()
        
        if case .completed = status {
            // Expected
        } else {
            XCTFail("Expected completed status")
        }
    }
    
    func testWaitForUpdateCompletion() async throws {
        let transceiver = MockAPDUTransceiver()
        // First two polls return updating, third returns completed
        await transceiver.setResponses([
            APDUResponse(data: Data([0x01]), sw1: 0x90, sw2: 0x00), // updating
            APDUResponse(data: Data([0x01]), sw1: 0x90, sw2: 0x00), // updating
            APDUResponse(data: Data([0x00]), sw1: 0x90, sw2: 0x00)  // completed
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        try await controller.waitForUpdateCompletion(maxAttempts: 10, pollingInterval: 0.01)
    }
    
    func testWaitForUpdateTimeout() async {
        let transceiver = MockAPDUTransceiver()
        // Always return updating
        await transceiver.setResponses(Array(repeating: APDUResponse(data: Data([0x01]), sw1: 0x90, sw2: 0x00), count: 10))
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        
        do {
            try await controller.waitForUpdateCompletion(maxAttempts: 5, pollingInterval: 0.01)
            XCTFail("Should have thrown timeout error")
        } catch EZSignEPaperError.updateTimeout {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFullUpdateSequence() async throws {
        let transceiver = MockAPDUTransceiver()
        
        // Prepare responses for full sequence
        var responses: [APDUResponse] = []
        
        // 1. Authentication
        responses.append(APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00))
        
        // 2. Image data transfer (small image with no compression)
        let image = EZSignEPaperImage(fillColor: .white)
        let processor = ImageDataProcessor(compressor: NoCompressor())
        let fragments = try processor.processImage(image)
        
        for _ in fragments {
            responses.append(APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00))
        }
        
        // 3. Start update
        responses.append(APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00))
        
        // 4. Poll status (completed immediately)
        responses.append(APDUResponse(data: Data([0x00]), sw1: 0x90, sw2: 0x00))
        
        await transceiver.setResponses(responses)
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        try await controller.authenticateAndUpdate(image, maxAttempts: 10, pollingInterval: 0.01)
    }
}
