# EZSignEPaper Examples

This directory contains example code for using the EZSignEPaper Swift Package.

## Basic Example - Solid Color Display

The simplest way to update the display with a solid color:

```swift
import EZSignEPaper

// Create a white screen
let image = EZSignEPaperImage(fillColor: .white)

// Update via NFC (iOS only)
let updater = EZSignEPaperNFCUpdater()
updater.updateDisplay(image,
    onProgress: { status in
        print("Progress: \(status)")
    },
    onComplete: {
        print("Display updated successfully!")
    },
    onError: { error in
        print("Error: \(error.localizedDescription)")
    }
)
```

## Drawing Custom Patterns

Create a custom image with patterns:

```swift
import EZSignEPaper

// Create a black background
var pixels = Array(repeating: Array(repeating: ColorIndex.black, count: 400), count: 300)

// Draw a red rectangle
for y in 50..<100 {
    for x in 50..<150 {
        pixels[y][x] = .red
    }
}

// Draw a yellow circle (approximate)
let centerX = 300
let centerY = 150
let radius = 50

for y in 0..<300 {
    for x in 0..<400 {
        let dx = x - centerX
        let dy = y - centerY
        if dx*dx + dy*dy < radius*radius {
            pixels[y][x] = .yellow
        }
    }
}

let image = try EZSignEPaperImage(pixels: pixels)

// Update display
let updater = EZSignEPaperNFCUpdater()
updater.updateDisplay(image,
    onProgress: { print($0) },
    onComplete: { print("Done!") },
    onError: { print("Error: \($0)") }
)
```

## Advanced Usage - Manual Control

For more control over the update process:

```swift
import EZSignEPaper
import CoreNFC

class MyNFCController: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    
    func startUpdate(with image: EZSignEPaperImage) {
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.alertMessage = "Hold iPhone near e-paper display"
        session?.begin()
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard case let .iso7816(tag) = tags.first else {
            session.invalidate(errorMessage: "Invalid tag type")
            return
        }
        
        session.connect(to: tags.first!) { error in
            guard error == nil else {
                session.invalidate(errorMessage: "Connection failed")
                return
            }
            
            Task {
                do {
                    let transceiver = NFCAPDUTransceiver(tag: tag)
                    let controller = EZSignEPaperController(transceiver: transceiver)
                    
                    // Create your image
                    let image = EZSignEPaperImage(fillColor: .white)
                    
                    // Execute update sequence
                    try await controller.authenticate()
                    try await controller.sendImageData(image)
                    try await controller.startUpdate()
                    try await controller.waitForUpdateCompletion()
                    
                    session.invalidate()
                    print("Update completed!")
                } catch {
                    session.invalidate(errorMessage: error.localizedDescription)
                }
            }
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("Session invalidated: \(error.localizedDescription)")
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session is ready
    }
}

// Usage
let controller = MyNFCController()
let image = EZSignEPaperImage(fillColor: .red)
controller.startUpdate(with: image)
```

## Testing Without Hardware

Use mock transceivers for testing:

```swift
import EZSignEPaper

// Create a mock transceiver
let transceiver = MockAPDUTransceiver()

// Prepare mock responses
transceiver.responses = [
    // Authentication response
    APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00),
    // Image transfer responses (multiple)
    APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00),
    // ... more responses
]

// Create controller with mock
let controller = EZSignEPaperController(
    transceiver: transceiver,
    compressor: NoCompressor() // Skip compression for testing
)

// Test your logic
Task {
    try await controller.authenticate()
    // ... test your code
}
```

## Custom Compression

Provide your own LZO compressor:

```swift
import EZSignEPaper

class MyLZOCompressor: DataCompressor {
    func compress(_ data: Data) throws -> Data {
        // Call your LZO library
        // For example, using a C library wrapper:
        // return lzo_compress(data)
        
        // Placeholder implementation
        return data
    }
}

let controller = EZSignEPaperController(
    transceiver: transceiver,
    compressor: MyLZOCompressor()
)
```

## Error Handling

Comprehensive error handling example:

```swift
import EZSignEPaper

let updater = EZSignEPaperNFCUpdater()
let image = EZSignEPaperImage(fillColor: .white)

updater.updateDisplay(image,
    onProgress: { status in
        print("Status: \(status)")
    },
    onComplete: {
        print("Success!")
    },
    onError: { error in
        switch error {
        case EZSignEPaperError.authenticationFailed:
            print("Authentication failed - check device")
        case EZSignEPaperError.updateTimeout:
            print("Update took too long")
        case EZSignEPaperError.communicationError(let msg):
            print("Communication error: \(msg)")
        case EZSignEPaperError.invalidImageSize(let msg):
            print("Invalid image: \(msg)")
        default:
            print("Unknown error: \(error.localizedDescription)")
        }
    }
)
```

## SwiftUI Integration

Example SwiftUI view:

```swift
import SwiftUI
import EZSignEPaper

struct EPaperUpdateView: View {
    @State private var status: String = "Ready"
    @State private var isUpdating: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(status)
                .font(.headline)
            
            Button("Update Display") {
                updateDisplay()
            }
            .disabled(isUpdating)
        }
        .padding()
    }
    
    func updateDisplay() {
        isUpdating = true
        status = "Starting update..."
        
        // Create image
        let image = EZSignEPaperImage(fillColor: .white)
        
        // Update
        let updater = EZSignEPaperNFCUpdater()
        updater.updateDisplay(image,
            onProgress: { progressStatus in
                DispatchQueue.main.async {
                    self.status = progressStatus
                }
            },
            onComplete: {
                DispatchQueue.main.async {
                    self.status = "Update completed!"
                    self.isUpdating = false
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    self.status = "Error: \(error.localizedDescription)"
                    self.isUpdating = false
                }
            }
        )
    }
}
```

## UIKit Integration

Example UIKit view controller:

```swift
import UIKit
import EZSignEPaper

class EPaperViewController: UIViewController {
    private let statusLabel = UILabel()
    private let updateButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Status label
        statusLabel.text = "Ready to update"
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Update button
        updateButton.setTitle("Update Display", for: .normal)
        updateButton.addTarget(self, action: #selector(updateTapped), for: .touchUpInside)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(updateButton)
        
        // Layout
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            
            updateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            updateButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20)
        ])
    }
    
    @objc private func updateTapped() {
        updateButton.isEnabled = false
        statusLabel.text = "Starting..."
        
        let image = EZSignEPaperImage(fillColor: .white)
        let updater = EZSignEPaperNFCUpdater()
        
        updater.updateDisplay(image,
            onProgress: { [weak self] status in
                DispatchQueue.main.async {
                    self?.statusLabel.text = status
                }
            },
            onComplete: { [weak self] in
                DispatchQueue.main.async {
                    self?.statusLabel.text = "Update completed!"
                    self?.updateButton.isEnabled = true
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                    self?.updateButton.isEnabled = true
                }
            }
        )
    }
}
```

## Notes

- NFC functionality requires an iOS device with NFC capability (iPhone 7 or later)
- Your app must include NFC usage descriptions in Info.plist
- The library handles the 20-second NFC timeout automatically
- For production use, consider implementing a proper LZO compressor
- Test your images thoroughly before deploying to hardware
