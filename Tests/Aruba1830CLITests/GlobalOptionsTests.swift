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
    
    func testResolveMacAliasFileURLUsesOverride() throws {
        var options = try GlobalOptions.parse([])
        options.macAliasFile = "custom/aliases.txt"
        let url = options.resolveMacAliasFileURL()
        XCTAssertEqual(url?.path, URL(fileURLWithPath: "custom/aliases.txt").path)
    }
    
    func testResolveMacAliasFileURLFindsDefaultFile() throws {
        let originalCWD = FileManager.default.currentDirectoryPath
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-alias-default-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(originalCWD)
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(tempDirectory.path))
        
        let defaultFile = tempDirectory.appendingPathComponent(".aruba1830-macaliases.txt")
        try "6c:4a:85:4f:7d:f4 default".write(to: defaultFile, atomically: true, encoding: .utf8)
        
        let options = try GlobalOptions.parse([])
        let url = options.resolveMacAliasFileURL()
        XCTAssertEqual(url?.lastPathComponent, ".aruba1830-macaliases.txt")
    }
    
    func testLoadMacAliasResolverReadsOverrideFile() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-alias-override-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        
        let aliasFile = tempDirectory.appendingPathComponent("aliases.txt")
        try "6c:4a:85:4f:7d:f4 AppleTV".write(to: aliasFile, atomically: true, encoding: .utf8)
        
        var options = try GlobalOptions.parse([])
        options.macAliasFile = aliasFile.path
        let resolver = options.loadMacAliasResolver()
        XCTAssertEqual(resolver.resolve("appletv"), "6c:4a:85:4f:7d:f4")
    }
    
    func testLoadMacAliasResolverReturnsEmptyWhenFileMissing() throws {
        let originalCWD = FileManager.default.currentDirectoryPath
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-alias-missing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(originalCWD)
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(tempDirectory.path))
        
        let options = try GlobalOptions.parse([])
        let resolver = options.loadMacAliasResolver()
        XCTAssertNil(resolver.resolve("does-not-exist"))
    }
}
