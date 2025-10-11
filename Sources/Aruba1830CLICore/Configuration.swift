import Foundation

public struct ArubaConfiguration: Sendable {
    public let host: String
    public let username: String
    public let password: String
    public let sessionToken: String?
    public let sessionCookie: String?
    
    public init(host: String, username: String, password: String, sessionToken: String? = nil, sessionCookie: String? = nil) {
        self.host = host
        self.username = username
        self.password = password
        self.sessionToken = sessionToken
        self.sessionCookie = sessionCookie
    }
    
    /// Load configuration from .env file
    public static func loadFromEnv(path: String = ".env") -> ArubaConfiguration? {
        guard let envData = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        var config: [String: String] = [:]
        
        for line in envData.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }
            
            // Parse KEY=VALUE
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            
            // Remove quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            
            config[key] = value
        }
        
        guard let host = config["ARUBA_HOST"],
              let username = config["ARUBA_USERNAME"],
              let password = config["ARUBA_PASSWORD"] else {
            return nil
        }
        
        let sessionToken = config["ARUBA_SESSION_TOKEN"]
        let sessionCookie = config["ARUBA_SESSION_COOKIE"]
        
        return ArubaConfiguration(
            host: host,
            username: username,
            password: password,
            sessionToken: sessionToken,
            sessionCookie: sessionCookie
        )
    }
    
    /// Merge with command-line options (CLI options take precedence)
    public func merged(
        host: String? = nil,
        username: String? = nil,
        password: String? = nil,
        sessionToken: String? = nil,
        sessionCookie: String? = nil
    ) -> ArubaConfiguration {
        return ArubaConfiguration(
            host: host ?? self.host,
            username: username ?? self.username,
            password: password ?? self.password,
            sessionToken: sessionToken ?? self.sessionToken,
            sessionCookie: sessionCookie ?? self.sessionCookie
        )
    }
}

