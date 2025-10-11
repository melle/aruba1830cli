import XCTest
@testable import Aruba1830CLICore

final class ModelsTests: XCTestCase {
    
    // MARK: - ArubaSession Tests
    
    func testSessionInit() {
        let session = ArubaSession(
            host: "192.168.7.68",
            sessionToken: "cs2d4faf80",
            sessionCookie: "UserId=192.168.7.206&hash&",
            username: "admin"
        )
        
        XCTAssertEqual(session.host, "192.168.7.68")
        XCTAssertEqual(session.sessionToken, "cs2d4faf80")
        XCTAssertEqual(session.username, "admin")
    }
    
    func testSessionBaseURL() {
        let session = ArubaSession(
            host: "192.168.7.68",
            sessionToken: "cs2d4faf80",
            sessionCookie: "test",
            username: "admin"
        )
        
        XCTAssertEqual(session.baseURL, "http://192.168.7.68/cs2d4faf80/hpe")
    }
    
    func testSessionCookieHeader() {
        let session = ArubaSession(
            host: "192.168.7.68",
            sessionToken: "cs2d4faf80",
            sessionCookie: "UserId=192.168.7.206&hash&",
            username: "admin"
        )
        
        XCTAssertEqual(session.cookieHeader, "sessionID=UserId=192.168.7.206&hash&; userName=admin")
    }
    
    // MARK: - MACTableEntry Tests
    
    func testMACTableEntry() {
        let entry = MACTableEntry(
            vlanID: 1,
            macAddress: "00:11:22:33:44:55",
            interfaceType: 1,
            interfaceName: "5",
            addressType: 3
        )
        
        XCTAssertEqual(entry.vlanID, 1)
        XCTAssertEqual(entry.macAddress, "00:11:22:33:44:55")
        XCTAssertEqual(entry.portNumber, "5")
        XCTAssertTrue(entry.isDynamic)
    }
    
    func testMACTableEntryStatic() {
        let entry = MACTableEntry(
            vlanID: 1,
            macAddress: "00:11:22:33:44:55",
            interfaceType: 1,
            interfaceName: "5",
            addressType: 1
        )
        
        XCTAssertFalse(entry.isDynamic)
    }
    
    // MARK: - PortInfo Tests
    
    func testPortInfoEnabled() {
        let port = PortInfo(
            interfaceName: "1",
            adminState: 1,
            operationalStatus: "up",
            speed: "1000",
            duplex: "full"
        )
        
        XCTAssertTrue(port.isEnabled)
        XCTAssertEqual(port.portNumber, "1")
    }
    
    func testPortInfoDisabled() {
        let port = PortInfo(
            interfaceName: "2",
            adminState: 2
        )
        
        XCTAssertFalse(port.isEnabled)
    }
    
    // MARK: - ActionStatus Tests
    
    func testActionStatusSuccess() {
        let status = ActionStatus(
            statusCode: 0,
            statusString: "OK",
            deviceStatusCode: 0
        )
        
        XCTAssertTrue(status.isSuccess)
    }
    
    func testActionStatusFailure() {
        let status = ActionStatus(
            statusCode: 3,
            statusString: "Error",
            deviceStatusCode: 1
        )
        
        XCTAssertFalse(status.isSuccess)
    }
    
    // MARK: - VLANInfo Tests
    
    func testVLANInfo() {
        let vlan = VLANInfo(
            vlanID: 10,
            vlanName: "Production",
            status: "active"
        )
        
        XCTAssertEqual(vlan.vlanID, 10)
        XCTAssertEqual(vlan.vlanName, "Production")
        XCTAssertEqual(vlan.status, "active")
    }
    
    // MARK: - PoEPortInfo Tests
    
    func testPoEPortInfo() {
        let poe = PoEPortInfo(
            interfaceName: "1",
            poeEnabled: true,
            powerStatus: "delivering",
            powerUsage: 15.5
        )
        
        XCTAssertTrue(poe.poeEnabled)
        XCTAssertEqual(poe.interfaceName, "1")
        XCTAssertEqual(poe.powerUsage, 15.5)
    }
}

