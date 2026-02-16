import Foundation

/// Update status result from polling
public enum UpdateStatus {
    case updating
    case completed
}

/// Main controller for EZ Sign EPaper display operations
public class EZSignEPaperController {
    private let transceiver: APDUTransceiver
    private let processor: ImageDataProcessor
    
    /// Initialize controller with a transceiver
    /// - Parameters:
    ///   - transceiver: APDU transceiver for communication
    ///   - compressor: Data compressor (defaults to LZO)
    public init(transceiver: APDUTransceiver, compressor: DataCompressor = LZOCompressor()) {
        self.transceiver = transceiver
        self.processor = ImageDataProcessor(compressor: compressor)
    }
    
    /// Authenticate with the device
    /// - Throws: EZSignEPaperError if authentication fails
    public func authenticate() async throws {
        let apdu = EZSignEPaperCommand.authenticate()
        let response = try await transceiver.transceive(apdu)
        
        guard response.isSuccess else {
            throw EZSignEPaperError.authenticationFailed
        }
    }
    
    /// Send image data to the device
    /// - Parameter image: Image to send
    /// - Throws: EZSignEPaperError if transfer fails
    public func sendImageData(_ image: EZSignEPaperImage) async throws {
        let fragments = try processor.processImage(image)
        let apdus = processor.fragmentsToAPDUs(fragments)
        
        for apdu in apdus {
            let response = try await transceiver.transceive(apdu)
            guard response.isSuccess else {
                throw EZSignEPaperError.communicationError("Image data transfer failed with status: \(String(format: "%04X", response.statusWord))")
            }
        }
    }
    
    /// Start screen update
    /// - Throws: EZSignEPaperError if update start fails
    public func startUpdate() async throws {
        let apdu = EZSignEPaperCommand.startUpdate()
        let response = try await transceiver.transceive(apdu)
        
        guard response.isSuccess else {
            throw EZSignEPaperError.communicationError("Failed to start update with status: \(String(format: "%04X", response.statusWord))")
        }
    }
    
    /// Poll update status
    /// - Returns: Update status (updating or completed)
    /// - Throws: EZSignEPaperError if polling fails
    public func pollUpdateStatus() async throws -> UpdateStatus {
        let apdu = EZSignEPaperCommand.pollUpdateStatus()
        let response = try await transceiver.transceive(apdu)
        
        guard response.isSuccess else {
            throw EZSignEPaperError.communicationError("Failed to poll status with status: \(String(format: "%04X", response.statusWord))")
        }
        
        guard let statusByte = response.data.first else {
            throw EZSignEPaperError.invalidResponse("No status byte in response")
        }
        
        return statusByte == 0x00 ? .completed : .updating
    }
    
    /// Wait for update to complete
    /// - Parameters:
    ///   - maxAttempts: Maximum number of polling attempts (default: 100)
    ///   - pollingInterval: Interval between polls in seconds (default: 0.5)
    /// - Throws: EZSignEPaperError if update times out or fails
    public func waitForUpdateCompletion(maxAttempts: Int = 100, pollingInterval: TimeInterval = 0.5) async throws {
        for _ in 0..<maxAttempts {
            let status = try await pollUpdateStatus()
            
            if case .completed = status {
                return
            }
            
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
        
        throw EZSignEPaperError.updateTimeout
    }
    
    /// Update display with image (complete flow without re-authentication)
    /// This performs: sendImageData -> startUpdate -> waitForCompletion
    /// Note: Authentication must be done separately before calling this
    /// - Parameters:
    ///   - image: Image to display
    ///   - maxAttempts: Maximum polling attempts
    ///   - pollingInterval: Polling interval
    /// - Throws: EZSignEPaperError if update fails
    public func updateDisplay(_ image: EZSignEPaperImage, maxAttempts: Int = 100, pollingInterval: TimeInterval = 0.5) async throws {
        try await sendImageData(image)
        try await startUpdate()
        try await waitForUpdateCompletion(maxAttempts: maxAttempts, pollingInterval: pollingInterval)
    }
    
    /// Full update sequence with authentication
    /// This is a convenience method that performs the complete update flow:
    /// authenticate -> sendImageData -> startUpdate -> waitForCompletion
    /// - Parameters:
    ///   - image: Image to display
    ///   - maxAttempts: Maximum polling attempts
    ///   - pollingInterval: Polling interval
    /// - Throws: EZSignEPaperError if update fails
    public func authenticateAndUpdate(_ image: EZSignEPaperImage, maxAttempts: Int = 100, pollingInterval: TimeInterval = 0.5) async throws {
        try await authenticate()
        try await updateDisplay(image, maxAttempts: maxAttempts, pollingInterval: pollingInterval)
    }
    
    /// Get screen type (optional diagnostic)
    /// - Returns: Screen type description
    /// - Throws: EZSignEPaperError if request fails
    public func getScreenType() async throws -> String {
        let apdu = EZSignEPaperCommand.getScreenType()
        let response = try await transceiver.transceive(apdu)
        
        guard response.isSuccess else {
            throw EZSignEPaperError.communicationError("Failed to get screen type")
        }
        
        return String(data: response.data, encoding: .utf8) ?? "Unknown"
    }
    
    /// Get device info (optional diagnostic)
    /// - Returns: Device information as data
    /// - Throws: EZSignEPaperError if request fails
    public func getDeviceInfo() async throws -> Data {
        let apdu = EZSignEPaperCommand.getDeviceInfo()
        let response = try await transceiver.transceive(apdu)
        
        guard response.isSuccess else {
            throw EZSignEPaperError.communicationError("Failed to get device info")
        }
        
        return response.data
    }
}
