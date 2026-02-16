# Protocol Specification

This document describes the communication protocol for the EZ Sign EPaper display based on the [original specification by @niw](https://gist.github.com/niw/3885b22d502bb1e145984d41568f202d).

## Display Specifications

- **Screen Size**: 400 × 300 pixels
- **Colors**: 4 colors (2 bits per pixel)
  - 0 = Black
  - 1 = White
  - 2 = Yellow
  - 3 = Red
- **Communication**: ISO7816 APDU over NFC

## Communication Sequence

### Minimal Update Sequence

1. **Authentication**: `0020 00010420091210` → `9000`
2. **Image Data Transfer**: Multiple `F0D3 ...` commands
3. **Start Update**: `F0D4 858000` → `9000`
4. **Update Completion Polling**: `F0DE 000001`
   - Response: `01 9000` = Updating
   - Response: `00 9000` = Completed

## Image Data Format

### Block Structure

- Height divided into blocks of 20 rows each
- Total blocks: 300 rows / 20 rows = **15 blocks**
- Block numbers: `0` to `14`

### Uncompressed Block Size

- Bytes per row: 400 pixels / 4 pixels per byte = **100 bytes**
- Bytes per block: 100 bytes × 20 rows = **2000 bytes**

### Pixel Packing

4 pixels are packed into 1 byte:

```
byte = p0 | (p1 << 2) | (p2 << 4) | (p3 << 6)
```

Where `p0..p3` are color indices (0-3).

**Important**: Bytes within a row are ordered **right to left**.

Example:
- Pixels 0-3 go into the last byte of the row (byte 99)
- Pixels 396-399 go into the first byte of the row (byte 0)

### Compression

Each 2000-byte block is compressed using **LZO1X-1** (`lzo1x_1_compress`) algorithm.

## APDU Command: F0D3 (Image Transfer)

### Format

```
CLA INS P1 P2 Lc Data...
```

- **CLA**: `F0`
- **INS**: `D3`
- **P1**: `00`
- **P2**:
  - `00` = Fragment within block
  - `01` = Last fragment of block
- **Lc**: `2 + len(compressedFragment)`
- **Data**:
  - `blockNo` (1 byte)
  - `fragNo` (1 byte)
  - `compressedFragment` (variable length)

### Fragmentation

- Maximum fragment size: **250 bytes** (`0xFC - 2`)
- Compressed blocks larger than 250 bytes must be split into multiple fragments
- Fragments are reassembled on the device by:
  1. Concatenating fragments with same `blockNo` in `fragNo` order
  2. When `P2=01` is received, the block is complete
  3. Decompressing the complete block to 2000 bytes

### Example 1: Single Fragment Block

```
F0D300011600000255555555552000000000000000B10000110000
```

Breaking down:
- `F0 D3 00 01 16` - Header (P2=01 means last fragment, Lc=0x16=22)
- `00` - blockNo=0
- `00` - fragNo=0
- `0255555555552000000000000000B10000110000` - Compressed data (20 bytes)

### Example 2: Multi-Fragment Block

First fragment:
```
F0D30000FC020002...
```

- `P2=00` (not last)
- `Lc=0xFC` (252 bytes total, 250 for compressed data)
- `blockNo=2`
- `fragNo=0`

Additional fragments follow with same `blockNo` and incrementing `fragNo`, until final fragment with `P2=01`.

## APDU Commands

### Authentication (0020)

```
CLA INS P1 P2 Lc Data...
00  20  00 01 05 04 20 09 12 10
```

Response: `9000` on success

### Start Update (F0D4)

```
CLA INS P1 P2 Lc Data...
F0  D4  00 00 03 85 80 00
```

Response: `9000` on success

**Note**: This only initiates the update. The display will not refresh until update is complete.

### Poll Update Status (F0DE)

```
CLA INS P1 P2 Lc Data...
F0  DE  00 00 03 00 00 01
```

Response:
- `01 9000` - Update in progress
- `00 9000` - Update completed

### Optional: Get Screen Type (F0D8)

```
CLA INS P1 P2 Lc Data...
F0  D8  00 00 08 00 00 05 00 00 00 00 0E
```

Response: `"4_color Screen"` + `9000`

### Optional: Get Device Info (00D1)

```
CLA INS P1 P2 Lc
00  D1  00 00 00
```

Response: Device information + `9000`

## Status Words

- `9000` - Success
- `6700` - Length/format error
- `6D00` - INS not supported
- `6A86` - Invalid P1/P2

## CoreNFC Implementation Notes

### 20-Second Timeout Issue

`NFCTagReaderSession.connect(to:)` disconnects after approximately 20 seconds.

**Problem**: If you send all image data (`F0D3`), then start update (`F0D4`) and poll for completion (`F0DE`), the session may timeout before display refresh completes.

**Solution**: Use `restartPolling()` to extend the session:

1. Send image data (`F0D3` commands)
2. Call `session.restartPolling()`
3. Wait for reconnection
4. Re-authenticate (`0020`)
5. Start update (`F0D4`)
6. Poll for completion (`F0DE`)

This gives you an additional 20 seconds for the update to complete.

### Implementation

```swift
// Step 1: Send image data
try await controller.sendImageData(image)

// Step 2: Restart polling
session.restartPolling()
await Task.sleep(nanoseconds: 1_000_000_000) // Wait for reconnection

// Step 3: Re-authenticate
try await controller.authenticate()

// Step 4: Start update
try await controller.startUpdate()

// Step 5: Wait for completion
try await controller.waitForUpdateCompletion()
```

## Data Flow Summary

```
[App] → Authentication (0020)
[Device] ← 9000

[App] → Block 0, Fragment 0 (F0D3, P2=00 or 01)
[Device] ← 9000
[App] → Block 0, Fragment 1 (if needed)
[Device] ← 9000
... (repeat for all fragments of all blocks)

[App] → Start Update (F0D4)
[Device] ← 9000

[App] → Poll Status (F0DE)
[Device] ← 01 9000 (updating)
[App] → Poll Status (F0DE)
[Device] ← 01 9000 (still updating)
[App] → Poll Status (F0DE)
[Device] ← 00 9000 (completed!)
```

## Implementation in This Library

This library implements the complete protocol:

- `ColorIndex` - 4-color enumeration
- `EZSignEPaperImage` - Image representation with pixel packing
- `ImageDataProcessor` - Block compression and fragmentation
- `APDU` / `APDUResponse` - Command/response structures
- `EZSignEPaperCommand` - Factory for protocol commands
- `APDUTransceiver` - Communication interface
- `NFCAPDUTransceiver` - CoreNFC implementation
- `EZSignEPaperController` - High-level controller
- `EZSignEPaperNFCHelper` / `EZSignEPaperNFCUpdater` - NFC session management

## References

- Original specification: https://gist.github.com/niw/3885b22d502bb1e145984d41568f202d
- ISO7816 APDU: https://en.wikipedia.org/wiki/Smart_card_application_protocol_data_unit
- LZO Compression: http://www.oberhumer.com/opensource/lzo/
