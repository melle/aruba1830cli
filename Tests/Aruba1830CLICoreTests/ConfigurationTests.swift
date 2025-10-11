import XCTest
@testable import Aruba1830CLICore

final class ConfigurationTests: XCTestCase {
    
    var tempEnvPath: String!
    
    override func setUp() {
        super.setUp()
        tempEnvPath = NSTemporaryDirectory() + "test_\(UUID().uuidString).env"
    }
    
    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempEnvPath) {
            try? FileManager.default.removeItem(atPath: tempEnvPath)
        }
        super.tearDown()
    }
    
    func testLoadFromEnvFile() throws {
        let envContent = """
        ARUBA_HOST=192.168.7.68
        ARUBA_USERNAME=admin
        ARUBA_PASSWORD=secret
        ARUBA_SESSION_TOKEN=cs2d4faf80
        """
        
        try envContent.write(toFile: tempEnvPath, atomically: true, encoding: .utf8)
        
        let config = ArubaConfiguration.loadFromEnv(path: tempEnvPath)
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.host, "192.168.7.68")
        XCTAssertEqual(config?.username, "admin")
        XCTAssertEqual(config?.password, "secret")
        XCTAssertEqual(config?.sessionToken, "cs2d4faf80")
    }
    
    func testLoadFromEnvFileWithQuotes() throws {
        let envContent = """
        ARUBA_HOST="192.168.7.68"
        ARUBA_USERNAME='admin'
        ARUBA_PASSWORD="my password with spaces"
        ARUBA_SESSION_TOKEN=cs2d4faf80
        """
        
        try envContent.write(toFile: tempEnvPath, atomically: true, encoding: .utf8)
        
        let config = ArubaConfiguration.loadFromEnv(path: tempEnvPath)
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.host, "192.168.7.68")
        XCTAssertEqual(config?.username, "admin")
        XCTAssertEqual(config?.password, "my password with spaces")
        XCTAssertEqual(config?.sessionToken, "cs2d4faf80")
    }
    
    func testLoadFromEnvFileWithComments() throws {
        let envContent = """
        # This is a comment
        ARUBA_HOST=192.168.7.68
        
        # Another comment
        ARUBA_USERNAME=admin
        ARUBA_PASSWORD=secret
        ARUBA_SESSION_TOKEN=cs2d4faf80
        """
        
        try envContent.write(toFile: tempEnvPath, atomically: true, encoding: .utf8)
        
        let config = ArubaConfiguration.loadFromEnv(path: tempEnvPath)
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.host, "192.168.7.68")
    }
    
    func testLoadFromNonExistentFile() {
        let config = ArubaConfiguration.loadFromEnv(path: "/nonexistent/path/.env")
        XCTAssertNil(config)
    }
    
    func testLoadFromIncompleteEnvFile() throws {
        let envContent = """
        ARUBA_HOST=192.168.7.68
        ARUBA_USERNAME=admin
        # Missing PASSWORD and SESSION_TOKEN
        """
        
        try envContent.write(toFile: tempEnvPath, atomically: true, encoding: .utf8)
        
        let config = ArubaConfiguration.loadFromEnv(path: tempEnvPath)
        XCTAssertNil(config)
    }
    
    func testConfigurationMerge() {
        let baseConfig = ArubaConfiguration(
            host: "192.168.7.68",
            username: "admin",
            password: "secret",
            sessionToken: "cs2d4faf80"
        )
        
        let mergedConfig = baseConfig.merged(
            host: "192.168.1.1",
            username: "newuser"
        )
        
        XCTAssertEqual(mergedConfig.host, "192.168.1.1")
        XCTAssertEqual(mergedConfig.username, "newuser")
        XCTAssertEqual(mergedConfig.password, "secret")
        XCTAssertEqual(mergedConfig.sessionToken, "cs2d4faf80")
    }
    
    func testConfigurationMergeWithNilValues() {
        let baseConfig = ArubaConfiguration(
            host: "192.168.7.68",
            username: "admin",
            password: "secret",
            sessionToken: "cs2d4faf80"
        )
        
        let mergedConfig = baseConfig.merged()
        
        XCTAssertEqual(mergedConfig.host, baseConfig.host)
        XCTAssertEqual(mergedConfig.username, baseConfig.username)
        XCTAssertEqual(mergedConfig.password, baseConfig.password)
        XCTAssertEqual(mergedConfig.sessionToken, baseConfig.sessionToken)
    }
}

