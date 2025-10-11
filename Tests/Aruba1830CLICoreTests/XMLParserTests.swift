import XCTest
@testable import Aruba1830CLICore

final class XMLParserTests: XCTestCase {
    
    var parser: ArubaXMLParser!
    
    override func setUp() {
        super.setUp()
        parser = ArubaXMLParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - ForwardingTable Parsing
    
    func testParseForwardingTable() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
        <DeviceConfiguration>
          <ForwardingTable type="section">
            <Entry>
              <VLANID>1</VLANID>
              <MACAddress>00:11:22:33:44:55</MACAddress>
              <interfaceType>1</interfaceType>
              <interfaceName>5</interfaceName>
              <addressType>3</addressType>
            </Entry>
            <Entry>
              <VLANID>10</VLANID>
              <MACAddress>aa:bb:cc:dd:ee:ff</MACAddress>
              <interfaceType>1</interfaceType>
              <interfaceName>8</interfaceName>
              <addressType>1</addressType>
            </Entry>
          </ForwardingTable>
        </DeviceConfiguration>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let entries = try parser.parseForwardingTable(data: data)
        
        XCTAssertEqual(entries.count, 2)
        
        XCTAssertEqual(entries[0].vlanID, 1)
        XCTAssertEqual(entries[0].macAddress, "00:11:22:33:44:55")
        XCTAssertEqual(entries[0].interfaceName, "5")
        XCTAssertTrue(entries[0].isDynamic)
        
        XCTAssertEqual(entries[1].vlanID, 10)
        XCTAssertEqual(entries[1].macAddress, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(entries[1].interfaceName, "8")
        XCTAssertFalse(entries[1].isDynamic)
    }
    
    func testParseEmptyForwardingTable() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
        <DeviceConfiguration>
          <ForwardingTable type="section">
          </ForwardingTable>
        </DeviceConfiguration>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let entries = try parser.parseForwardingTable(data: data)
        
        XCTAssertEqual(entries.count, 0)
    }
    
    // MARK: - Ports Parsing
    
    func testParsePorts() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
        <DeviceConfiguration>
          <Standard802_3List type="section">
            <Entry>
              <interfaceName>1</interfaceName>
              <adminState>1</adminState>
              <operationalStatus>up</operationalStatus>
              <speed>1000</speed>
              <duplex>full</duplex>
            </Entry>
            <Entry>
              <interfaceName>2</interfaceName>
              <adminState>2</adminState>
            </Entry>
          </Standard802_3List>
        </DeviceConfiguration>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let ports = try parser.parsePorts(data: data)
        
        XCTAssertEqual(ports.count, 2)
        
        XCTAssertEqual(ports[0].interfaceName, "1")
        XCTAssertTrue(ports[0].isEnabled)
        XCTAssertEqual(ports[0].operationalStatus, "up")
        
        XCTAssertEqual(ports[1].interfaceName, "2")
        XCTAssertFalse(ports[1].isEnabled)
    }
    
    // MARK: - ActionStatus Parsing
    
    func testParseActionStatusSuccess() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
          <ActionStatus>
            <version>1.0</version>
            <statusCode>0</statusCode>
            <statusString>OK</statusString>
            <deviceStatusCode>0</deviceStatusCode>
          </ActionStatus>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let status = try parser.parseActionStatus(data: data)
        
        XCTAssertEqual(status.statusCode, 0)
        XCTAssertEqual(status.statusString, "OK")
        XCTAssertTrue(status.isSuccess)
    }
    
    func testParseActionStatusError() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
          <ActionStatus>
            <statusCode>3</statusCode>
            <statusString>Configuration failed</statusString>
            <deviceStatusCode>1</deviceStatusCode>
          </ActionStatus>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let status = try parser.parseActionStatus(data: data)
        
        XCTAssertEqual(status.statusCode, 3)
        XCTAssertEqual(status.statusString, "Configuration failed")
        XCTAssertFalse(status.isSuccess)
    }
    
    // MARK: - VLANs Parsing
    
    func testParseVLANs() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
        <DeviceConfiguration>
          <VLANList type="section">
            <Entry>
              <VLANID>1</VLANID>
              <vlanName>default</vlanName>
              <status>active</status>
            </Entry>
            <Entry>
              <VLANID>10</VLANID>
              <vlanName>Production</vlanName>
              <status>active</status>
            </Entry>
          </VLANList>
        </DeviceConfiguration>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let vlans = try parser.parseVLANs(data: data)
        
        XCTAssertEqual(vlans.count, 2)
        
        XCTAssertEqual(vlans[0].vlanID, 1)
        XCTAssertEqual(vlans[0].vlanName, "default")
        XCTAssertEqual(vlans[0].status, "active")
        
        XCTAssertEqual(vlans[1].vlanID, 10)
        XCTAssertEqual(vlans[1].vlanName, "Production")
    }
    
    // MARK: - PoE Parsing
    
    func testParsePoEPorts() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <ResponseData>
        <DeviceConfiguration>
          <PoEPSEInterfaceList type="section">
            <Entry>
              <interfaceName>1</interfaceName>
              <poeEnabled>1</poeEnabled>
              <powerStatus>delivering</powerStatus>
              <powerUsage>15.5</powerUsage>
            </Entry>
            <Entry>
              <interfaceName>2</interfaceName>
              <poeEnabled>2</poeEnabled>
            </Entry>
          </PoEPSEInterfaceList>
        </DeviceConfiguration>
        </ResponseData>
        """
        
        let data = xml.data(using: .utf8)!
        let ports = try parser.parsePoEPorts(data: data)
        
        XCTAssertEqual(ports.count, 2)
        
        XCTAssertEqual(ports[0].interfaceName, "1")
        XCTAssertTrue(ports[0].poeEnabled)
        XCTAssertEqual(ports[0].powerStatus, "delivering")
        XCTAssertEqual(ports[0].powerUsage, 15.5)
        
        XCTAssertEqual(ports[1].interfaceName, "2")
        XCTAssertFalse(ports[1].poeEnabled)
    }
}

