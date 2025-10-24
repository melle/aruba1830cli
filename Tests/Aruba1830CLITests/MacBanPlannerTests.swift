import XCTest
@testable import Aruba1830CLI
import Aruba1830CLICore

final class MacBanPlannerTests: XCTestCase {
    func testActionReturnsBanWhenMacFoundWithoutSavedPort() {
        let entries = [
            MACTableEntry(vlanID: 1, macAddress: "aa:bb:cc:dd:ee:ff", interfaceType: 1, interfaceName: "1", addressType: 3)
        ]
        
        let action = MacBanPlanner.action(savedPort: nil, macEntries: entries)
        XCTAssertEqual(action, .banOn(port: "1", previousPort: nil))
    }
    
    func testActionReturnsAlreadyBannedWhenOnlySavedPortExists() {
        let action = MacBanPlanner.action(savedPort: "5", macEntries: [])
        XCTAssertEqual(action, .alreadyBanned(port: "5"))
    }
    
    func testActionReturnsNilWhenNoDataAvailable() {
        let action = MacBanPlanner.action(savedPort: nil, macEntries: [])
        XCTAssertNil(action)
    }
    
    func testActionDetectsPortChange() {
        let entries = [
            MACTableEntry(vlanID: 1, macAddress: "aa:bb:cc:dd:ee:ff", interfaceType: 1, interfaceName: "3", addressType: 3)
        ]
        
        let action = MacBanPlanner.action(savedPort: "1", macEntries: entries)
        XCTAssertEqual(action, .banOn(port: "3", previousPort: "1"))
    }
}
