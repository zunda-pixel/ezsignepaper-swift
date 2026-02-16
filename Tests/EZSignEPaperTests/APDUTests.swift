import XCTest
@testable import EZSignEPaper

final class APDUTests: XCTestCase {
    func testAPDUSerialization() {
        let apdu = APDU(cla: 0xF0, ins: 0xD3, p1: 0x00, p2: 0x01, data: Data([0x01, 0x02, 0x03]))
        let serialized = apdu.serialize()
        
        // Should be: CLA INS P1 P2 Lc Data...
        XCTAssertEqual(serialized.count, 8) // 5 header + 3 data
        XCTAssertEqual(serialized[0], 0xF0) // CLA
        XCTAssertEqual(serialized[1], 0xD3) // INS
        XCTAssertEqual(serialized[2], 0x00) // P1
        XCTAssertEqual(serialized[3], 0x01) // P2
        XCTAssertEqual(serialized[4], 0x03) // Lc (length)
        XCTAssertEqual(serialized[5], 0x01) // Data
        XCTAssertEqual(serialized[6], 0x02)
        XCTAssertEqual(serialized[7], 0x03)
    }
    
    func testAPDUSerializationNoData() {
        let apdu = APDU(cla: 0x00, ins: 0x20, p1: 0x00, p2: 0x01)
        let serialized = apdu.serialize()
        
        XCTAssertEqual(serialized.count, 4) // Just header
        XCTAssertEqual(serialized[0], 0x00)
        XCTAssertEqual(serialized[1], 0x20)
        XCTAssertEqual(serialized[2], 0x00)
        XCTAssertEqual(serialized[3], 0x01)
    }
    
    func testAPDUResponseSuccess() {
        let response = APDUResponse(data: Data([0x01, 0x02]), sw1: 0x90, sw2: 0x00)
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.statusWord, 0x9000)
        XCTAssertEqual(response.data.count, 2)
    }
    
    func testAPDUResponseFailure() {
        let response = APDUResponse(data: Data(), sw1: 0x67, sw2: 0x00)
        
        XCTAssertFalse(response.isSuccess)
        XCTAssertEqual(response.statusWord, 0x6700)
    }
    
    func testAuthenticateCommand() {
        let apdu = EZSignEPaperCommand.authenticate()
        let serialized = apdu.serialize()
        
        // Expected: 0020 00010420091210
        XCTAssertEqual(serialized[0], 0x00) // CLA
        XCTAssertEqual(serialized[1], 0x20) // INS
        XCTAssertEqual(serialized[2], 0x00) // P1
        XCTAssertEqual(serialized[3], 0x01) // P2
        XCTAssertEqual(serialized[4], 0x05) // Lc = 5
        XCTAssertEqual(serialized[5], 0x04)
        XCTAssertEqual(serialized[6], 0x20)
        XCTAssertEqual(serialized[7], 0x09)
        XCTAssertEqual(serialized[8], 0x12)
        XCTAssertEqual(serialized[9], 0x10)
    }
    
    func testImageDataTransferCommand() {
        let fragmentData = Data([0x11, 0x22, 0x33])
        let apdu = EZSignEPaperCommand.imageDataTransfer(
            blockNo: 2,
            fragNo: 0,
            compressedFragment: fragmentData,
            isLastFragment: true
        )
        let serialized = apdu.serialize()
        
        XCTAssertEqual(serialized[0], 0xF0) // CLA
        XCTAssertEqual(serialized[1], 0xD3) // INS
        XCTAssertEqual(serialized[2], 0x00) // P1
        XCTAssertEqual(serialized[3], 0x01) // P2 (last fragment)
        XCTAssertEqual(serialized[4], 0x05) // Lc = 2 + 3
        XCTAssertEqual(serialized[5], 0x02) // blockNo
        XCTAssertEqual(serialized[6], 0x00) // fragNo
        XCTAssertEqual(serialized[7], 0x11) // data
        XCTAssertEqual(serialized[8], 0x22)
        XCTAssertEqual(serialized[9], 0x33)
    }
    
    func testStartUpdateCommand() {
        let apdu = EZSignEPaperCommand.startUpdate()
        let serialized = apdu.serialize()
        
        // Expected: F0D4 858000
        XCTAssertEqual(serialized[0], 0xF0)
        XCTAssertEqual(serialized[1], 0xD4)
        XCTAssertEqual(serialized[4], 0x03) // Lc = 3
        XCTAssertEqual(serialized[5], 0x85)
        XCTAssertEqual(serialized[6], 0x80)
        XCTAssertEqual(serialized[7], 0x00)
    }
    
    func testPollUpdateStatusCommand() {
        let apdu = EZSignEPaperCommand.pollUpdateStatus()
        let serialized = apdu.serialize()
        
        // Expected: F0DE 000001
        XCTAssertEqual(serialized[0], 0xF0)
        XCTAssertEqual(serialized[1], 0xDE)
        XCTAssertEqual(serialized[4], 0x03) // Lc = 3
        XCTAssertEqual(serialized[5], 0x00)
        XCTAssertEqual(serialized[6], 0x00)
        XCTAssertEqual(serialized[7], 0x01)
    }
}
