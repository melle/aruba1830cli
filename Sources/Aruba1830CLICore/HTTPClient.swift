import Foundation

public final class ArubaHTTPClient: Sendable {
    private let session: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request (for authentication)
    
    /// Make a generic HTTP request with full control over headers and redirect behavior
    /// Returns: (responseBody, headerValue) tuple where headerValue is the raw response headers as string
    public func makeRequest(
        url: String,
        method: String,
        headers: [String: String],
        body: String?,
        followRedirects: Bool
    ) async throws -> (String, String?) {
        guard let requestURL = URL(string: url) else {
            throw ArubaError.invalidURL(url)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }
        
        do {
            // Use the main session which follows redirects by default
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArubaError.invalidResponse
            }
            
            // Extract headers we care about
            let location = httpResponse.value(forHTTPHeaderField: "Location")
            let setCookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie")
            
            // For 302 redirects when not following redirects, return the Location header
            if !followRedirects && httpResponse.statusCode == 302 {
                let responseBody = location ?? ""
                return (responseBody, setCookie)
            }
            
            // For normal responses, return the body
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            return (responseBody, setCookie)
        } catch let error as ArubaError {
            throw error
        } catch {
            throw ArubaError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - GET Request
    
    public func get(url: String, arubaSession: ArubaSession) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw ArubaError.invalidURL(url)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue(arubaSession.cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArubaError.invalidResponse
            }
            
            try validateHTTPResponse(httpResponse)
            
            return data
        } catch let error as ArubaError {
            throw error
        } catch {
            throw ArubaError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - POST Request
    
    public func post(url: String, arubaSession: ArubaSession, xmlBody: String) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw ArubaError.invalidURL(url)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue(arubaSession.cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = xmlBody.data(using: .utf8)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ArubaError.invalidResponse
            }
            
            try validateHTTPResponse(httpResponse)
            
            return data
        } catch let error as ArubaError {
            throw error
        } catch {
            throw ArubaError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Response Validation
    
    private func validateHTTPResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw ArubaError.authenticationFailed("Unauthorized")
        case 403:
            throw ArubaError.authenticationFailed("Forbidden")
        case 404:
            throw ArubaError.httpError(404, "Not Found")
        case 500...599:
            throw ArubaError.httpError(response.statusCode, "Server Error")
        default:
            throw ArubaError.httpError(response.statusCode, "HTTP Error")
        }
    }
}

// MARK: - URLSession Delegate for Redirect Control

private final class RedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let followRedirects: Bool
    
    init(followRedirects: Bool) {
        self.followRedirects = followRedirects
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if followRedirects {
            completionHandler(request)
        } else {
            // Don't follow redirect, return nil
            completionHandler(nil)
        }
    }
}

