# EZSignEPaper

A Swift Package library for controlling EZ Sign EPaper displays via NFC.

## Overview

This library provides a generic Swift interface for the 400x300 4-color (Black, White, Yellow, Red) e-paper display that can be updated via NFC communication. It implements the ISO7816 APDU protocol based on the [specification by @niw](https://gist.github.com/niw/3885b22d502bb1e145984d41568f202d).

## Features

- ✅ Support for 400x300 pixel displays with 4 colors
- ✅ NFC communication via CoreNFC (iOS 18+)
- ✅ Image data compression and automatic fragmentation
- ✅ Automatic update polling and completion detection
- ✅ Clean async/await API with Swift Concurrency support
- ✅ Full Sendable conformance for thread-safe operation
- ✅ Mock transceivers for testing
- ✅ Comprehensive error handling
- ✅ Uses Swift Algorithms for efficient data processing

## Requirements

- Swift 6.0+
- iOS 18.0+ / macOS 15.0+
- For NFC functionality: iOS device with NFC capability

## Dependencies

- [Swift Algorithms](https://github.com/apple/swift-algorithms) - For efficient chunking and data processing

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/zunda-pixel/ezsignepaper-swift.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File > Add Packages...
2. Enter the repository URL: `https://github.com/zunda-pixel/ezsignepaper-swift`

## Usage

### Basic Usage (iOS with NFC)

```swift
import EZSignEPaper

// Create an image (400x300 pixels)
var pixels = Array(repeating: Array(repeating: ColorIndex.white, count: 400), count: 300)

// Draw something (e.g., a red rectangle)
for y in 50..<100 {
    for x in 50..<150 {
        pixels[y][x] = .red
    }
}

let image = try EZSignEPaperImage(pixels: pixels)

// Update display via NFC
let updater = EZSignEPaperNFCUpdater()
updater.updateDisplay(image,
    onProgress: { status in
        print("Status: \(status)")
    },
    onComplete: {
        print("Display updated successfully!")
    },
    onError: { error in
        print("Error: \(error)")
    }
)
```

### Advanced Usage with Custom Control

```swift
import EZSignEPaper
import CoreNFC

class MyNFCHandler: NSObject, NFCTagReaderSessionDelegate {
    func updateDisplay(with image: EZSignEPaperImage) {
        let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.begin()
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard case let .iso7816(tag) = tags.first else { return }
        
        session.connect(to: tags.first!) { error in
            guard error == nil else { return }
            
            Task {
                // Create transceiver and controller
                let transceiver = NFCAPDUTransceiver(tag: tag)
                let controller = EZSignEPaperController(transceiver: transceiver)
                
                do {
                    // Step 1: Authenticate
                    try await controller.authenticate()
                    
                    // Step 2: Send image
                    let image = EZSignEPaperImage(fillColor: .white)
                    try await controller.sendImageData(image)
                    
                    // Step 3: Start update
                    try await controller.startUpdate()
                    
                    // Step 4: Wait for completion
                    try await controller.waitForUpdateCompletion()
                    
                    session.invalidate()
                } catch {
                    session.invalidate(errorMessage: error.localizedDescription)
                }
            }
        }
    }
    
    // ... other delegate methods
}
```

### Creating Images

#### Fill with a single color

```swift
let image = EZSignEPaperImage(fillColor: .white)
```

#### Create from pixel array

```swift
var pixels = Array(repeating: Array(repeating: ColorIndex.white, count: 400), count: 300)

// Set individual pixels
pixels[y][x] = .black

let image = try EZSignEPaperImage(pixels: pixels)
```

### Using Custom Compressor

The library uses LZO1X-1 compression by default (with a mock implementation). You can provide your own compressor:

```swift
class MyCompressor: DataCompressor {
    func compress(_ data: Data) throws -> Data {
        // Your compression implementation
        return compressedData
    }
}

let controller = EZSignEPaperController(
    transceiver: transceiver,
    compressor: MyCompressor()
)
```

Or use no compression for testing:

```swift
let controller = EZSignEPaperController(
    transceiver: transceiver,
    compressor: NoCompressor()
)
```

## Architecture

### Core Components

- **ColorIndex**: 4-color enumeration (Black, White, Yellow, Red)
- **EZSignEPaperImage**: Image representation with 400x300 pixels
- **APDU/APDUResponse**: ISO7816 command/response structures
- **ImageDataProcessor**: Handles compression and fragmentation
- **EZSignEPaperController**: Main controller for display operations
- **NFCAPDUTransceiver**: NFC communication layer (iOS)

### Protocol Flow

1. **Authenticate**: Send authentication command (`0020 00010420091210`)
2. **Send Image Data**: Transfer compressed image blocks via `F0D3` commands
3. **Start Update**: Initiate screen refresh (`F0D4 858000`)
4. **Poll Status**: Wait for completion via `F0DE` polling

### Image Data Format

- Display: 400×300 pixels, 4 colors (2 bits per pixel)
- Packing: 4 pixels per byte
- Blocks: 15 blocks of 20 rows each (2000 bytes uncompressed)
- Compression: LZO1X-1
- Fragmentation: Max 250 bytes per fragment

## NFC Session Management

The library handles the 20-second NFC timeout issue mentioned in the spec. The `EZSignEPaperNFCUpdater` automatically:
1. Sends image data
2. Restarts NFC polling if needed (for long operations)
3. Re-authenticates after restart
4. Starts display update
5. Polls for completion

## Testing

The library includes comprehensive tests:

```bash
swift test
```

Use `MockAPDUTransceiver` for unit testing without hardware:

```swift
let transceiver = MockAPDUTransceiver()
transceiver.responses = [
    APDUResponse(data: Data(), sw1: 0x90, sw2: 0x00)
]

let controller = EZSignEPaperController(transceiver: transceiver)
```

## Examples

See the `Examples` directory for complete sample applications (coming soon).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is available under the MIT license.

## Credits

Protocol specification by [@niw](https://github.com/niw): https://gist.github.com/niw/3885b22d502bb1e145984d41568f202d

## Related Resources

- [EZ Sign EPaper Protocol Specification](https://gist.github.com/niw/3885b22d502bb1e145984d41568f202d)
- [Apple CoreNFC Documentation](https://developer.apple.com/documentation/corenfc)