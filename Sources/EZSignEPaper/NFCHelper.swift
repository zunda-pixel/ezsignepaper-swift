import Foundation
#if canImport(CoreNFC)
import CoreNFC

/// Helper class for managing NFC sessions for EZ Sign EPaper
/// Note: According to the spec, NFCTagReaderSession.connect(to:) disconnects after 20 seconds.
/// To handle long operations, you may need to use restartPolling() and re-authenticate.
@available(iOS 18.0, *)
@MainActor
public final class EZSignEPaperNFCHelper: NSObject, @unchecked Sendable {
    private var session: NFCTagReaderSession?
    private var currentTag: NFCISO7816Tag?
    private var onTagDiscovered: (@Sendable (NFCISO7816Tag) -> Void)?
    private var onError: (@Sendable (Error) -> Void)?
    
    public override init() {
        super.init()
    }
    
    /// Start NFC reading session
    /// - Parameters:
    ///   - alertMessage: Message to show in NFC dialog
    ///   - onTagDiscovered: Callback when tag is discovered
    ///   - onError: Callback when error occurs
    public func startSession(alertMessage: String = "Hold your iPhone near the e-paper display",
                            onTagDiscovered: @escaping @Sendable (NFCISO7816Tag) -> Void,
                            onError: @escaping @Sendable (Error) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            onError(EZSignEPaperError.communicationError("NFC not available on this device"))
            return
        }
        
        self.onTagDiscovered = onTagDiscovered
        self.onError = onError
        
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.alertMessage = alertMessage
        session?.begin()
    }
    
    /// Restart polling (useful for extending the 20-second timeout)
    /// After restarting, you need to re-authenticate
    public func restartPolling() {
        session?.restartPolling()
    }
    
    /// Invalidate the session
    /// - Parameter errorMessage: Optional error message to display
    public func invalidateSession(errorMessage: String? = nil) {
        if let errorMessage = errorMessage {
            session?.invalidate(errorMessage: errorMessage)
        } else {
            session?.invalidate()
        }
    }
}

@available(iOS 18.0, *)
extension EZSignEPaperNFCHelper: NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session is ready
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // Check if this is a user cancellation (not really an error)
        if let nfcError = error as? NFCReaderError,
           nfcError.code == .readerSessionInvalidationErrorUserCanceled {
            return
        }
        
        Task { @MainActor in
            self.onError?(error)
        }
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "No tags found")
            return
        }
        
        guard case let .iso7816(tag) = firstTag else {
            session.invalidate(errorMessage: "Unsupported tag type")
            return
        }
        
        session.connect(to: firstTag) { [weak self] error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.onError?(error)
                }
                return
            }
            
            Task { @MainActor in
                self?.currentTag = tag
                self?.onTagDiscovered?(tag)
            }
        }
    }
}

/// Convenience method for updating display via NFC
/// This handles the NFC session lifecycle and update process
@available(iOS 18.0, *)
@MainActor
public final class EZSignEPaperNFCUpdater: @unchecked Sendable {
    private let helper: EZSignEPaperNFCHelper
    private let compressor: DataCompressor
    
    public init(compressor: DataCompressor = LZOCompressor()) {
        self.helper = EZSignEPaperNFCHelper()
        self.compressor = compressor
    }
    
    /// Update display via NFC
    /// - Parameters:
    ///   - image: Image to display
    ///   - alertMessage: NFC dialog message
    ///   - needsPollingRestart: Whether to restart polling for long operations (default: true for operations > 15s)
    ///   - onProgress: Progress callback (optional)
    ///   - onComplete: Completion callback
    ///   - onError: Error callback
    public func updateDisplay(_ image: EZSignEPaperImage,
                             alertMessage: String = "Hold your iPhone near the e-paper display",
                             needsPollingRestart: Bool = true,
                             onProgress: (@Sendable (String) -> Void)? = nil,
                             onComplete: @escaping @Sendable () -> Void,
                             onError: @escaping @Sendable (Error) -> Void) {
        helper.startSession(alertMessage: alertMessage) { [weak self] tag in
            guard let self = self else { return }
            
            Task {
                do {
                    let transceiver = NFCAPDUTransceiver(tag: tag)
                    let controller = EZSignEPaperController(transceiver: transceiver, compressor: self.compressor)
                    
                    // Step 1: Authenticate
                    onProgress?("Authenticating...")
                    try await controller.authenticate()
                    
                    // Step 2: Send image data
                    onProgress?("Sending image data...")
                    try await controller.sendImageData(image)
                    
                    // Step 3: Restart polling if needed (to get another 20 seconds)
                    if needsPollingRestart {
                        onProgress?("Reconnecting...")
                        await MainActor.run {
                            self.helper.restartPolling()
                        }
                        
                        // Wait a bit for reconnection
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        
                        // Re-authenticate after restart
                        try await controller.authenticate()
                    }
                    
                    // Step 4: Start update
                    onProgress?("Starting display update...")
                    try await controller.startUpdate()
                    
                    // Step 5: Wait for completion
                    onProgress?("Waiting for display to refresh...")
                    try await controller.waitForUpdateCompletion(maxAttempts: 60, pollingInterval: 1.0)
                    
                    onProgress?("Update completed!")
                    await MainActor.run {
                        self.helper.invalidateSession()
                    }
                    onComplete()
                    
                } catch {
                    await MainActor.run {
                        self.helper.invalidateSession(errorMessage: "Update failed: \(error.localizedDescription)")
                    }
                    onError(error)
                }
            }
        } onError: { error in
            onError(error)
        }
    }
}
#endif
