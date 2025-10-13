import XCTest
@testable import Aruba1830CLI

final class GlobalOptionsTests: XCTestCase {
    func testDefaultPortMacFileUsesSanitizedHost() throws {
        let options = try GlobalOptions.parse([])
        let url = options.resolvePortMacFilePath(host: "192.168.1.1")
        XCTAssertEqual(url.lastPathComponent, ".aruba1830_192.168.1.1.ports")
    }
    
    func testOverridePortMacFilePath() throws {
        var options = try GlobalOptions.parse([])
        options.portMacFile = "custom/ports.json"
        let url = options.resolvePortMacFilePath(host: "example")
        XCTAssertEqual(url.path, URL(fileURLWithPath: "custom/ports.json").path)
    }
    
    func testHostSanitizationReplacesUnsupportedCharacters() throws {
        let options = try GlobalOptions.parse([])
        let url = options.resolvePortMacFilePath(host: "lab-switch:01")
        XCTAssertEqual(url.lastPathComponent, ".aruba1830_lab-switch_01.ports")
    }
}
