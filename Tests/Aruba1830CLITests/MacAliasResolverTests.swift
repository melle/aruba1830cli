import XCTest
@testable import Aruba1830CLI

final class MacAliasResolverTests: XCTestCase {
    func testResolveReturnsNormalizedMAC() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-aliases-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        
        let fileURL = tempDirectory.appendingPathComponent("aliases.txt")
        let contents = """
        6c:4a:85:4f:7d:f4    AppleTV
        5C-ED-F4-B0-88-CE\tAndroidArthur
        # Comment line should be ignored
        """
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let resolver = try MacAliasResolver.load(from: fileURL)
        XCTAssertEqual(resolver.resolve("AppleTV"), "6c:4a:85:4f:7d:f4")
        XCTAssertEqual(resolver.resolve("appletv"), "6c:4a:85:4f:7d:f4")
        XCTAssertEqual(resolver.resolve("ANDROIDARTHUR"), "5c:ed:f4:b0:88:ce")
        XCTAssertNil(resolver.resolve("UnknownDevice"))
    }
}
