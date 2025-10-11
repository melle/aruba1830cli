import Foundation

// MARK: - Session

public struct ArubaSession: Sendable {
    public let host: String
    public let sessionToken: String
    public let sessionCookie: String
    public let username: String
    
    public init(host: String, sessionToken: String, sessionCookie: String, username: String) {
        self.host = host
        self.sessionToken = sessionToken
        self.sessionCookie = sessionCookie
        self.username = username
    }
    
    public var baseURL: String {
        "http://\(host)/\(sessionToken)/hpe"
    }
    
    public var cookieHeader: String {
        "sessionID=\(sessionCookie); userName=\(username)"
    }
}

// MARK: - MAC Table

public struct MACTableEntry: Sendable, Equatable {
    public let vlanID: Int
    public let macAddress: String
    public let interfaceType: Int
    public let interfaceName: String
    public let addressType: Int
    
    public init(vlanID: Int, macAddress: String, interfaceType: Int, interfaceName: String, addressType: Int) {
        self.vlanID = vlanID
        self.macAddress = macAddress
        self.interfaceType = interfaceType
        self.interfaceName = interfaceName
        self.addressType = addressType
    }
    
    public var isDynamic: Bool { addressType == 3 }
    public var portNumber: String { interfaceName }
}

// MARK: - Port

public struct PortInfo: Sendable, Equatable {
    public let interfaceName: String
    public let adminState: Int
    public let operationalStatus: String?
    public let speed: String?
    public let duplex: String?
    
    public init(interfaceName: String, adminState: Int, operationalStatus: String? = nil, speed: String? = nil, duplex: String? = nil) {
        self.interfaceName = interfaceName
        self.adminState = adminState
        self.operationalStatus = operationalStatus
        self.speed = speed
        self.duplex = duplex
    }
    
    public var isEnabled: Bool { adminState == 1 }
    public var portNumber: String { interfaceName }
}

public struct PortStatistics: Sendable, Equatable {
    public let interfaceName: String
    public let rxBytes: Int64
    public let txBytes: Int64
    public let rxPackets: Int64
    public let txPackets: Int64
    public let rxErrors: Int64
    public let txErrors: Int64
    
    public init(interfaceName: String, rxBytes: Int64, txBytes: Int64, rxPackets: Int64, txPackets: Int64, rxErrors: Int64, txErrors: Int64) {
        self.interfaceName = interfaceName
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.rxPackets = rxPackets
        self.txPackets = txPackets
        self.rxErrors = rxErrors
        self.txErrors = txErrors
    }
}

// MARK: - VLAN

public struct VLANInfo: Sendable, Equatable {
    public let vlanID: Int
    public let vlanName: String
    public let status: String?
    
    public init(vlanID: Int, vlanName: String, status: String? = nil) {
        self.vlanID = vlanID
        self.vlanName = vlanName
        self.status = status
    }
}

// MARK: - System

public struct SystemInfo: Sendable, Equatable {
    public let deviceName: String
    public let model: String
    public let serialNumber: String
    public let firmwareVersion: String
    public let macAddress: String
    
    public init(deviceName: String, model: String, serialNumber: String, firmwareVersion: String, macAddress: String) {
        self.deviceName = deviceName
        self.model = model
        self.serialNumber = serialNumber
        self.firmwareVersion = firmwareVersion
        self.macAddress = macAddress
    }
}

public struct LogEntry: Sendable, Equatable {
    public let timestamp: String
    public let severity: String
    public let message: String
    
    public init(timestamp: String, severity: String, message: String) {
        self.timestamp = timestamp
        self.severity = severity
        self.message = message
    }
}

// MARK: - PoE

public struct PoEPortInfo: Sendable, Equatable {
    public let interfaceName: String
    public let poeEnabled: Bool
    public let powerStatus: String?
    public let powerUsage: Double?
    
    public init(interfaceName: String, poeEnabled: Bool, powerStatus: String? = nil, powerUsage: Double? = nil) {
        self.interfaceName = interfaceName
        self.poeEnabled = poeEnabled
        self.powerStatus = powerStatus
        self.powerUsage = powerUsage
    }
}

// MARK: - Action Status

public struct ActionStatus: Sendable, Equatable {
    public let statusCode: Int
    public let statusString: String
    public let deviceStatusCode: Int
    
    public init(statusCode: Int, statusString: String, deviceStatusCode: Int) {
        self.statusCode = statusCode
        self.statusString = statusString
        self.deviceStatusCode = deviceStatusCode
    }
    
    public var isSuccess: Bool { statusCode == 0 }
}

