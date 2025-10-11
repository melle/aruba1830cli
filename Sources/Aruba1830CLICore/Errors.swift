import Foundation

public enum ArubaError: Error, Sendable, Equatable {
    case invalidURL(String)
    case httpError(Int, String)
    case authenticationFailed(String)
    case sessionExpired
    case configurationFailed(String)
    case parsingError(String)
    case networkError(String)
    case invalidResponse
    case portNotFound(String)
    case multipleMACsOnPort(String, Int)  // port, count
    case invalidMACAddress(String)
    case invalidCredentials
    case missingCredentials
    case missingArgument(String)
}

extension ArubaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .sessionExpired:
            return "Session expired. Please log in again."
        case .configurationFailed(let reason):
            return "Configuration failed: \(reason)"
        case .parsingError(let details):
            return "Failed to parse response: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .invalidResponse:
            return "Invalid response from switch"
        case .portNotFound(let port):
            return "Port not found: \(port)"
        case .multipleMACsOnPort(let port, let count):
            return "Multiple MAC addresses (\(count)) found on port \(port). Use --force to disable anyway."
        case .invalidMACAddress(let mac):
            return "Invalid MAC address format: \(mac)"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .missingCredentials:
            return "Missing credentials. Provide via --host, --user, --password or .env file"
        case .missingArgument(let message):
            return message
        }
    }
}

