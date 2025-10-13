import XCTest
@testable import Aruba1830CLI

final class PortActivityLogTests: XCTestCase {
    func testRecordCreatesFileAndNormalizesMACs() async throws {
        let (log, fileURL, directoryURL) = try makeLog()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        
        try await log.load()
        try await log.record(port: "1", macs: ["AA-BB-CC-11-22-33", "aa:bb:cc:11:22:33"])
        
        let snapshot = try await log.snapshot()
        XCTAssertEqual(snapshot["1"], ["aa:bb:cc:11:22:33"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testRemovePortDeletesFileWhenNoEntriesRemain() async throws {
        let (log, fileURL, directoryURL) = try makeLog()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        
        try await log.load()
        try await log.record(port: "1", macs: ["00:11:22:33:44:55"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        try await log.remove(port: "1")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testPortLookupUsesNormalizedMAC() async throws {
        let (log, _, directoryURL) = try makeLog()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        
        try await log.load()
        try await log.record(port: "5", macs: ["00:11:22:33:44:55"])
        
        let lookup = try await log.port(forMAC: "00-11-22-33-44-55")
        XCTAssertEqual(lookup, "5")
    }
    
    private func makeLog() throws -> (PortActivityLog, URL, URL) {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("ports.json")
        let log = PortActivityLog(fileURL: fileURL)
        return (log, fileURL, directoryURL)
    }
}
