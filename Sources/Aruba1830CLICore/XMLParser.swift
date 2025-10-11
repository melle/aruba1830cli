import Foundation

public final class ArubaXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var currentElement = ""
    private var currentValue = ""
    private var currentEntry: [String: String] = [:]
    private var entries: [[String: String]] = []
    private var elementStack: [String] = []
    private var actionStatus: ActionStatus?
    
    public override init() {
        super.init()
    }
    
    // MARK: - Public Parsing Methods
    
    public func parseForwardingTable(data: Data) throws -> [MACTableEntry] {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return entries.compactMap { dict in
            guard let vlanIDStr = dict["VLANID"],
                  let vlanID = Int(vlanIDStr),
                  let macAddress = dict["MACAddress"],
                  let interfaceTypeStr = dict["interfaceType"],
                  let interfaceType = Int(interfaceTypeStr),
                  let interfaceName = dict["interfaceName"],
                  let addressTypeStr = dict["addressType"],
                  let addressType = Int(addressTypeStr) else {
                return nil
            }
            
            return MACTableEntry(
                vlanID: vlanID,
                macAddress: macAddress,
                interfaceType: interfaceType,
                interfaceName: interfaceName,
                addressType: addressType
            )
        }
    }
    
    public func parsePorts(data: Data) throws -> [PortInfo] {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return entries.compactMap { dict in
            guard let interfaceName = dict["interfaceName"],
                  let adminStateStr = dict["adminState"],
                  let adminState = Int(adminStateStr) else {
                return nil
            }
            
            return PortInfo(
                interfaceName: interfaceName,
                adminState: adminState,
                operationalStatus: dict["operationalStatus"],
                speed: dict["speed"],
                duplex: dict["duplex"]
            )
        }
    }
    
    public func parseVLANs(data: Data) throws -> [VLANInfo] {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return entries.compactMap { dict in
            guard let vlanIDStr = dict["VLANID"],
                  let vlanID = Int(vlanIDStr) else {
                return nil
            }
            
            return VLANInfo(
                vlanID: vlanID,
                vlanName: dict["vlanName"] ?? "",
                status: dict["status"]
            )
        }
    }
    
    public func parseSystemInfo(data: Data) throws -> SystemInfo? {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        guard let dict = entries.first else { return nil }
        
        return SystemInfo(
            deviceName: dict["deviceName"] ?? "",
            model: dict["model"] ?? dict["modelName"] ?? "",
            serialNumber: dict["serialNumber"] ?? "",
            firmwareVersion: dict["firmwareVersion"] ?? dict["swVersion"] ?? "",
            macAddress: dict["macAddress"] ?? dict["systemMACAddress"] ?? ""
        )
    }
    
    public func parseLogs(data: Data) throws -> [LogEntry] {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return entries.compactMap { dict in
            guard let timestamp = dict["timestamp"] ?? dict["logTime"],
                  let message = dict["message"] ?? dict["logText"] else {
                return nil
            }
            
            return LogEntry(
                timestamp: timestamp,
                severity: dict["severity"] ?? dict["logLevel"] ?? "INFO",
                message: message
            )
        }
    }
    
    public func parsePoEPorts(data: Data) throws -> [PoEPortInfo] {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return entries.compactMap { dict in
            guard let interfaceName = dict["interfaceName"] else {
                return nil
            }
            
            let poeEnabled = (dict["poeEnabled"] ?? dict["adminEnabled"]) == "1"
            let powerUsage = dict["powerUsage"].flatMap { Double($0) }
            
            return PoEPortInfo(
                interfaceName: interfaceName,
                poeEnabled: poeEnabled,
                powerStatus: dict["powerStatus"] ?? dict["detectionStatus"],
                powerUsage: powerUsage
            )
        }
    }
    
    public func parseActionStatus(data: Data) throws -> ActionStatus {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        if let status = actionStatus {
            return status
        }
        
        // Fallback: try to parse from entries
        if let dict = entries.first {
            let statusCode = Int(dict["statusCode"] ?? "0") ?? 0
            let statusString = dict["statusString"] ?? "Unknown"
            let deviceStatusCode = Int(dict["deviceStatusCode"] ?? "0") ?? 0
            
            return ActionStatus(
                statusCode: statusCode,
                statusString: statusString,
                deviceStatusCode: deviceStatusCode
            )
        }
        
        throw ArubaError.parsingError("No ActionStatus found in response")
    }
    
    // MARK: - XMLParserDelegate
    
    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentValue = ""
        elementStack.append(elementName)
        
        if elementName == "Entry" {
            currentEntry = [:]
        } else if elementName == "ActionStatus" {
            currentEntry = [:]
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedValue.isEmpty && elementName != "Entry" && elementName != "ActionStatus" {
            currentEntry[elementName] = trimmedValue
        }
        
        if elementName == "Entry" {
            entries.append(currentEntry)
            currentEntry = [:]
        } else if elementName == "ActionStatus" {
            let statusCode = Int(currentEntry["statusCode"] ?? "0") ?? 0
            let statusString = currentEntry["statusString"] ?? "Unknown"
            let deviceStatusCode = Int(currentEntry["deviceStatusCode"] ?? "0") ?? 0
            
            actionStatus = ActionStatus(
                statusCode: statusCode,
                statusString: statusString,
                deviceStatusCode: deviceStatusCode
            )
            currentEntry = [:]
        }
        
        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
        
        currentValue = ""
    }
    
    private func reset() {
        currentElement = ""
        currentValue = ""
        currentEntry = [:]
        entries = []
        elementStack = []
        actionStatus = nil
    }
}

