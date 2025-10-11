import Foundation

public actor ArubaClient {
    private let httpClient: ArubaHTTPClient
    private let xmlParser: ArubaXMLParser
    
    public init() {
        self.httpClient = ArubaHTTPClient()
        self.xmlParser = ArubaXMLParser()
    }
    
    // MARK: - Authentication
    
    /// Performs full login flow: obtains session token via redirect, then logs in with credentials
    public func login(host: String, username: String, password: String, sessionToken: String? = nil, sessionCookie: String? = nil) async throws -> ArubaSession {
        // If both session token and cookie are provided, use them directly
        if let token = sessionToken, let cookie = sessionCookie {
            return ArubaSession(
                host: host,
                sessionToken: token,
                sessionCookie: cookie,
                username: username
            )
        }
        
        // Step 1: GET / to trigger 302 redirect and obtain session token
        guard let url = URL(string: "http://\(host)/") else {
            throw ArubaError.invalidURL("http://\(host)/")
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArubaError.invalidResponse
        }
        
        // The final URL after redirect will be: http://host/{token}/hpe/config/log_off_page.htm
        guard let finalURL = httpResponse.url?.absoluteString else {
            throw ArubaError.authenticationFailed("No final URL in response")
        }
        
        // Extract token from URL: http://192.168.7.68/cs2d4faf80/hpe/config/log_off_page.htm
        let token: String
        if let provided = sessionToken {
            token = provided
        } else if let extracted = extractSessionTokenFromURL(finalURL) {
            token = extracted
        } else {
            let html = String(data: data, encoding: .utf8) ?? ""
            // Try extracting from HTML as fallback
            if let tokenFromHTML = extractSessionTokenFromHTML(html, host: host) {
                token = tokenFromHTML
            } else {
                throw ArubaError.authenticationFailed("Failed to extract session token from URL: \(finalURL)")
            }
        }
        
        // Step 2: Login with credentials to get session cookie
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw ArubaError.invalidCredentials
        }
        let loginURLString = "http://\(host)/\(token)/htdocs/login/system.xml?action=login&user=\(encodedUsername)&password=\(encodedPassword)&ssd=true&"
        
        guard let loginURL = URL(string: loginURLString) else {
            throw ArubaError.invalidURL(loginURLString)
        }
        
        let (_, loginResponse) = try await URLSession.shared.data(from: loginURL)
        
        guard let httpLoginResponse = loginResponse as? HTTPURLResponse else {
            throw ArubaError.invalidResponse
        }
        
        // Extract sessionID cookie from Set-Cookie header
        let setCookieHeader = httpLoginResponse.value(forHTTPHeaderField: "Set-Cookie")
        
        let cookie: String
        if let provided = sessionCookie {
            cookie = provided
        } else if let extracted = extractSessionCookie(from: setCookieHeader) {
            cookie = extracted
        } else {
            throw ArubaError.authenticationFailed("Failed to obtain session cookie from login response. Set-Cookie: \(setCookieHeader ?? "nil")")
        }
        
        return ArubaSession(
            host: host,
            sessionToken: token,
            sessionCookie: cookie,
            username: username
        )
    }
    
    /// Create a session with existing credentials (for manual session management)
    /// Deprecated: Use login() instead for automatic authentication
    public func createSession(host: String, username: String, password: String, sessionToken: String, sessionCookie: String? = nil) async throws -> ArubaSession {
        // Use provided cookie or create a mock one
        let cookie = sessionCookie ?? "UserId=\(host)&mockSessionHash&"
        
        return ArubaSession(
            host: host,
            sessionToken: sessionToken,
            sessionCookie: cookie,
            username: username
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractSessionToken(from location: String) -> String? {
        // The location header is like: /cs2d4faf80/hpe/config/log_off_page.htm
        // Extract the session token (first path component after /)
        let components = location.split(separator: "/")
        if components.count >= 1 {
            return String(components[0])
        }
        return nil
    }
    
    private func extractSessionTokenFromURL(_ urlString: String) -> String? {
        // URL is like: http://192.168.7.68/cs2d4faf80/hpe/config/log_off_page.htm
        // Extract cs2d4faf80 (the token between host and /hpe/)
        let pattern = "://[^/]+/([a-z0-9]{8,12})/hpe/"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
           let range = Range(match.range(at: 1), in: urlString) {
            return String(urlString[range])
        }
        return nil
    }
    
    private func extractSessionTokenFromHTML(_ html: String, host: String) -> String? {
        // Look for URLs in the HTML that contain the session token
        // Format: /cs2d4faf80/hpe/... or http://host/cs2d4faf80/...
        
        // Try to find the form action which should contain the session token
        if html.range(of: "ACTION=\"./log_off_page.htm\"") != nil {
            // The current URL path should contain the token
            // Look for any href with the token pattern
            if html.range(of: "href=\"../css/") != nil {
                // This means we're at /{token}/hpe/config/log_off_page.htm
                // So the token is in the path before /hpe/
                // Look for script src or other absolute-ish paths
                if html.range(of: "src=\"../js/") != nil {
                    // We need to extract from a full path
                    // Let's try to find any src or href that has the full path
                    let pattern = "http://\(host)/([^/]+)/hpe/"
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                        if let range = Range(match.range(at: 1), in: html) {
                            return String(html[range])
                        }
                    }
                }
            }
        }
        
        // Alternative: search for the pattern /XXXXXXXXXX/hpe/ where X is alphanumeric
        let pattern = "/([a-z0-9]{8,12})/hpe/"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
        
        return nil
    }
    
    private func extractSessionCookie(from setCookieHeader: String?) -> String? {
        guard let setCookie = setCookieHeader else { return nil }
        
        // Extract sessionID=... from Set-Cookie header
        if let range = setCookie.range(of: "sessionID=([^;]+)", options: .regularExpression) {
            let cookieValue = String(setCookie[range])
            if let equalIndex = cookieValue.firstIndex(of: "=") {
                return String(cookieValue[cookieValue.index(after: equalIndex)...])
            }
        }
        return nil
    }
    
    // MARK: - MAC Table Operations
    
    public func getMACTable(session: ArubaSession) async throws -> [MACTableEntry] {
        let url = "\(session.baseURL)/wcd?{ForwardingTable}"
        let data = try await httpClient.get(url: url, arubaSession: session)
        return try xmlParser.parseForwardingTable(data: data)
    }
    
    public func getMACTableFiltered(session: ArubaSession, vlanID: Int? = nil, port: String? = nil) async throws -> [MACTableEntry] {
        let allEntries = try await getMACTable(session: session)
        
        var filtered = allEntries
        
        if let vlanID = vlanID {
            filtered = filtered.filter { $0.vlanID == vlanID }
        }
        
        if let port = port {
            filtered = filtered.filter { $0.interfaceName == port }
        }
        
        return filtered
    }
    
    public func findMACAddress(session: ArubaSession, macAddress: String) async throws -> [MACTableEntry] {
        let allEntries = try await getMACTable(session: session)
        let normalized = macAddress.lowercased().replacingOccurrences(of: "-", with: ":")
        return allEntries.filter { $0.macAddress.lowercased() == normalized }
    }
    
    // MARK: - Port Operations
    
    public func getPorts(session: ArubaSession) async throws -> [PortInfo] {
        let url = "\(session.baseURL)/wcd?{Standard802_3List}"
        let data = try await httpClient.get(url: url, arubaSession: session)
        return try xmlParser.parsePorts(data: data)
    }
    
    public func setPortState(session: ArubaSession, port: String, enabled: Bool) async throws {
        let adminState = enabled ? 1 : 2
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <DeviceConfiguration>
          <Standard802_3List action="set">
            <Entry>
              <adminState>\(adminState)</adminState>
              <interfaceName>\(port)</interfaceName>
              <interfaceDescription></interfaceDescription>
              <autoNegotiationAdminEnabled>1</autoNegotiationAdminEnabled>
              <adminAdvertisementList>100000000000000000000000</adminAdvertisementList>
            </Entry>
          </Standard802_3List>
          <STP action="set">
            <InterfaceList>
              <InterfaceEntry>
                <interfaceName>\(port)</interfaceName>
                <STPEnabled>1</STPEnabled>
                <timeRangeName></timeRangeName>
              </InterfaceEntry>
            </InterfaceList>
          </STP>
          <TimeBasedPortTable action="delete">
            <Entry>
              <interfaceName>\(port)</interfaceName>
              <timeRangeName></timeRangeName>
            </Entry>
          </TimeBasedPortTable>
        </DeviceConfiguration>
        """
        
        let url = "\(session.baseURL)/wcd?{Standard802_3List}{STP}{TimeBasedPortTable}"
        let data = try await httpClient.post(url: url, arubaSession: session, xmlBody: xml)
        let status = try xmlParser.parseActionStatus(data: data)
        
        guard status.isSuccess else {
            throw ArubaError.configurationFailed(status.statusString)
        }
    }
    
    // MARK: - Special: Disable Port by MAC Address
    
    public func disablePortByMAC(session: ArubaSession, macAddress: String, force: Bool = false) async throws {
        // Validate MAC address format
        let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        guard macAddress.range(of: macPattern, options: .regularExpression) != nil else {
            throw ArubaError.invalidMACAddress(macAddress)
        }
        
        // Find the MAC address
        let entries = try await findMACAddress(session: session, macAddress: macAddress)
        
        guard !entries.isEmpty else {
            throw ArubaError.parsingError("MAC address \(macAddress) not found in MAC table")
        }
        
        let port = entries[0].interfaceName
        
        // Check for multiple MACs on the same port
        let macsOnPort = try await getMACTableFiltered(session: session, port: port)
        
        if macsOnPort.count > 1 && !force {
            throw ArubaError.multipleMACsOnPort(port, macsOnPort.count)
        }
        
        // Disable the port
        try await setPortState(session: session, port: port, enabled: false)
    }
    
    // MARK: - System Operations
    
    public func getSystemInfo(session: ArubaSession) async throws -> SystemInfo? {
        let url = "\(session.baseURL)/wcd?{Units}"
        let data = try await httpClient.get(url: url, arubaSession: session)
        return try xmlParser.parseSystemInfo(data: data)
    }
    
    public func getLogs(session: ArubaSession) async throws -> [LogEntry] {
        let url = "\(session.baseURL)/wcd?{MemoryLogTable}"
        let data = try await httpClient.get(url: url, arubaSession: session)
        return try xmlParser.parseLogs(data: data)
    }
    
    // MARK: - VLAN Operations
    
    public func getVLANs(session: ArubaSession) async throws -> [VLANInfo] {
        let url = "\(session.baseURL)/wcd?{VLANList}"
        let data = try await httpClient.get(url: url, arubaSession: session)
        return try xmlParser.parseVLANs(data: data)
    }
    
    // MARK: - PoE Operations
    
    public func getPoEPorts(session: ArubaSession) async throws -> [PoEPortInfo] {
        let url = "\(session.baseURL)/wcd?{PoEPSEInterfaceList}"
        let data = try await httpClient.get(url: url, arubaSession: session)
        return try xmlParser.parsePoEPorts(data: data)
    }
    
    public func setPoEState(session: ArubaSession, port: String, enabled: Bool) async throws {
        let poeState = enabled ? 1 : 2
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <DeviceConfiguration>
          <PoEPSEInterfaceList action="set">
            <Entry>
              <interfaceName>\(port)</interfaceName>
              <adminEnabled>\(poeState)</adminEnabled>
            </Entry>
          </PoEPSEInterfaceList>
        </DeviceConfiguration>
        """
        
        let url = "\(session.baseURL)/wcd?{PoEPSEInterfaceList}"
        let data = try await httpClient.post(url: url, arubaSession: session, xmlBody: xml)
        let status = try xmlParser.parseActionStatus(data: data)
        
        guard status.isSuccess else {
            throw ArubaError.configurationFailed(status.statusString)
        }
    }
}

