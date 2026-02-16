import Testing
import Foundation
@testable import EZSignEPaper

@Suite("EZSignEPaper Controller Tests")
struct EZSignEPaperControllerTests {
    @Test("Authenticate success")
    func authenticateSuccess() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        try await controller.authenticate()
        
        // Should complete without error
    }
    
    @Test("Authenticate failure")
    func authenticateFailure() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data(), sw1: 0x67, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        
        await #expect(throws: EZSignEPaperError.authenticationFailed) {
            try await controller.authenticate()
        }
    }
    
    @Test("Start update")
    func startUpdate() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        try await controller.startUpdate()
    }
    
    @Test("Poll update status - updating")
    func pollUpdateStatusUpdating() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data([0x01]), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        let status = try await controller.pollUpdateStatus()
        
        #expect(status == .updating)
    }
    
    @Test("Poll update status - completed")
    func pollUpdateStatusCompleted() async throws {
        let transceiver = MockAPDUTransceiver()
        await transceiver.setResponses([
            APDUResponse(data: Data([0x00]), sw1: 0x90, sw2: 0x00)
        ])
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        let status = try await controller.pollUpdateStatus()
        
        #expect(status == .completed)
    }
    
    @Test("Wait for update completion")
    func waitForUpdateCompletion() async throws {
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
    
    @Test("Wait for update timeout")
    func waitForUpdateTimeout() async throws {
        let transceiver = MockAPDUTransceiver()
        // Always return updating
        await transceiver.setResponses(Array(repeating: APDUResponse(data: Data([0x01]), sw1: 0x90, sw2: 0x00), count: 10))
        
        let controller = EZSignEPaperController(transceiver: transceiver, compressor: NoCompressor())
        
        await #expect(throws: EZSignEPaperError.updateTimeout) {
            try await controller.waitForUpdateCompletion(maxAttempts: 5, pollingInterval: 0.01)
        }
    }
    
    @Test("Full update sequence")
    func fullUpdateSequence() async throws {
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
