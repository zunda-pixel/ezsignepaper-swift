import Testing
import Foundation
@testable import EZSignEPaper

@Suite("APDU Tests")
struct APDUTests {
    @Test("APDU serialization with data")
    func apduSerialization() {
        let apdu = APDU(cla: 0xF0, ins: 0xD3, p1: 0x00, p2: 0x01, data: Data([0x01, 0x02, 0x03]))
        let serialized = apdu.serialize()
        
        // Should be: CLA INS P1 P2 Lc Data...
        #expect(serialized.count == 8) // 5 header + 3 data
        #expect(serialized[0] == 0xF0) // CLA
        #expect(serialized[1] == 0xD3) // INS
        #expect(serialized[2] == 0x00) // P1
        #expect(serialized[3] == 0x01) // P2
        #expect(serialized[4] == 0x03) // Lc (length)
        #expect(serialized[5] == 0x01) // Data
        #expect(serialized[6] == 0x02)
        #expect(serialized[7] == 0x03)
    }
    
    @Test("APDU serialization without data")
    func apduSerializationNoData() {
        let apdu = APDU(cla: 0x00, ins: 0x20, p1: 0x00, p2: 0x01)
        let serialized = apdu.serialize()
        
        #expect(serialized.count == 4) // Just header
        #expect(serialized[0] == 0x00)
        #expect(serialized[1] == 0x20)
        #expect(serialized[2] == 0x00)
        #expect(serialized[3] == 0x01)
    }
    
    @Test("APDU response success")
    func apduResponseSuccess() {
        let response = APDUResponse(data: Data([0x01, 0x02]), sw1: 0x90, sw2: 0x00)
        
        #expect(response.isSuccess == true)
        #expect(response.statusWord == 0x9000)
        #expect(response.data.count == 2)
    }
    
    @Test("APDU response failure")
    func apduResponseFailure() {
        let response = APDUResponse(data: Data(), sw1: 0x67, sw2: 0x00)
        
        #expect(response.isSuccess == false)
        #expect(response.statusWord == 0x6700)
    }
    
    @Test("Authenticate command")
    func authenticateCommand() {
        let apdu = EZSignEPaperCommand.authenticate()
        let serialized = apdu.serialize()
        
        // Expected: 0020 00010420091210
        #expect(serialized[0] == 0x00) // CLA
        #expect(serialized[1] == 0x20) // INS
        #expect(serialized[2] == 0x00) // P1
        #expect(serialized[3] == 0x01) // P2
        #expect(serialized[4] == 0x05) // Lc = 5
        #expect(serialized[5] == 0x04)
        #expect(serialized[6] == 0x20)
        #expect(serialized[7] == 0x09)
        #expect(serialized[8] == 0x12)
        #expect(serialized[9] == 0x10)
    }
    
    @Test("Image data transfer command")
    func imageDataTransferCommand() {
        let fragmentData = Data([0x11, 0x22, 0x33])
        let apdu = EZSignEPaperCommand.imageDataTransfer(
            blockNo: 2,
            fragNo: 0,
            compressedFragment: fragmentData,
            isLastFragment: true
        )
        let serialized = apdu.serialize()
        
        #expect(serialized[0] == 0xF0) // CLA
        #expect(serialized[1] == 0xD3) // INS
        #expect(serialized[2] == 0x00) // P1
        #expect(serialized[3] == 0x01) // P2 (last fragment)
        #expect(serialized[4] == 0x05) // Lc = 2 + 3
        #expect(serialized[5] == 0x02) // blockNo
        #expect(serialized[6] == 0x00) // fragNo
        #expect(serialized[7] == 0x11) // data
        #expect(serialized[8] == 0x22)
        #expect(serialized[9] == 0x33)
    }
    
    @Test("Start update command")
    func startUpdateCommand() {
        let apdu = EZSignEPaperCommand.startUpdate()
        let serialized = apdu.serialize()
        
        // Expected: F0D4 858000
        #expect(serialized[0] == 0xF0)
        #expect(serialized[1] == 0xD4)
        #expect(serialized[4] == 0x03) // Lc = 3
        #expect(serialized[5] == 0x85)
        #expect(serialized[6] == 0x80)
        #expect(serialized[7] == 0x00)
    }
    
    @Test("Poll update status command")
    func pollUpdateStatusCommand() {
        let apdu = EZSignEPaperCommand.pollUpdateStatus()
        let serialized = apdu.serialize()
        
        // Expected: F0DE 000001
        #expect(serialized[0] == 0xF0)
        #expect(serialized[1] == 0xDE)
        #expect(serialized[4] == 0x03) // Lc = 3
        #expect(serialized[5] == 0x00)
        #expect(serialized[6] == 0x00)
        #expect(serialized[7] == 0x01)
    }
}
