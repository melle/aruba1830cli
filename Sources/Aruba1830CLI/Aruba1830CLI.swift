import Foundation
import ArgumentParser
import Aruba1830CLICore

@main
struct Aruba1830CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aruba1830",
        abstract: "CLI tool for managing Aruba 1830 switches",
        version: "1.0.0",
        subcommands: [
            MACTableCommand.self,
            PortCommand.self,
            SystemCommand.self,
            VLANCommand.self,
            PoECommand.self,
        ]
    )
}

// MARK: - Shared Options

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "Switch IP address or hostname")
    var host: String?
    
    @Option(name: .long, help: "Username for authentication")
    var user: String?
    
    @Option(name: .long, help: "Password for authentication")
    var password: String?
    
    @Option(name: .long, help: "Session token")
    var sessionToken: String?
    
    @Option(name: .long, help: "Session cookie (from browser)")
    var sessionCookie: String?
    
    @Option(name: .long, help: "Path to .env file")
    var envFile: String = ".env"
    
    @Option(name: .long, help: "Path to port MAC log file")
    var portMacFile: String?
    
    @Option(name: .long, help: "Path to MAC alias file")
    var macAliasFile: String?
    
    func getConfiguration() throws -> ArubaConfiguration {
        // Try to load from .env file first
        var config = ArubaConfiguration.loadFromEnv(path: envFile)
        
        // Merge with command-line options (CLI takes precedence)
        if let existingConfig = config {
            config = existingConfig.merged(
                host: host,
                username: user,
                password: password,
                sessionToken: sessionToken,
                sessionCookie: sessionCookie
            )
        } else if let host = host, let user = user, let password = password {
            config = ArubaConfiguration(host: host, username: user, password: password, sessionToken: sessionToken, sessionCookie: sessionCookie)
        }
        
        guard let finalConfig = config else {
            throw ArubaError.missingCredentials
        }
        
        return finalConfig
    }
    
    func resolvePortMacFilePath(host: String) -> URL {
        if let override = portMacFile, !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        
        let sanitizedHost = sanitizeForFilename(host)
        return URL(fileURLWithPath: ".aruba1830_\(sanitizedHost).ports")
    }
    
    func resolveMacAliasFileURL(fileManager: FileManager = .default) -> URL? {
        if let override = macAliasFile, !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        
        let defaultURL = URL(fileURLWithPath: ".aruba1830-macaliases.txt")
        guard fileManager.fileExists(atPath: defaultURL.path) else {
            return nil
        }
        return defaultURL
    }
    
    func loadMacAliasResolver(fileManager: FileManager = .default) -> MacAliasResolver {
        guard let url = resolveMacAliasFileURL(fileManager: fileManager) else {
            return .empty
        }
        
        do {
            return try MacAliasResolver.load(from: url)
        } catch {
            emitWarning("Failed to load MAC alias file at \(url.path): \(error)")
            return .empty
        }
    }
    
    private func sanitizeForFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var result = ""
        for scalar in value.unicodeScalars {
            if allowed.contains(scalar) {
                result.append(String(scalar))
            } else {
                result.append("_")
            }
        }
        return result
    }
}

private func emitWarning(_ message: String) {
    let output = "⚠️  \(message)\n"
    print(output)
}

private let macAddressPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"

// MARK: - MAC Table Command

struct MACTableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mac-table",
        abstract: "Display MAC address table"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .long, help: "Filter by VLAN ID")
    var vlan: Int?
    
    @Option(name: .long, help: "Filter by port number")
    var port: String?
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        let entries: [MACTableEntry]
        if vlan != nil || port != nil {
            entries = try await client.getMACTableFiltered(session: session, vlanID: vlan, port: port)
        } else {
            entries = try await client.getMACTable(session: session)
        }
        
        print("VLAN  MAC Address        Port  Type")
        print("----  -----------------  ----  -------")
        for entry in entries {
            let type = entry.isDynamic ? "Dynamic" : "Static"
            let vlanStr = String(format: "%-4d", entry.vlanID)
            let macStr = entry.macAddress.padding(toLength: 17, withPad: " ", startingAt: 0)
            let portStr = entry.portNumber.padding(toLength: 4, withPad: " ", startingAt: 0)
            print("\(vlanStr)  \(macStr)  \(portStr)  \(type)")
        }
        print("\nTotal: \(entries.count) entries")
    }
}

// MARK: - Port Command

struct PortCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "port",
        abstract: "Port management operations",
        subcommands: [
            PortListCommand.self,
            PortEnableCommand.self,
            MacBanCommand.self,
            PortDisableCommand.self,
        ]
    )
}

struct PortListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all ports"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        let ports = try await client.getPorts(session: session)
        
        print("Port  Status    ")
        print("----  ----------")
        for port in ports {
            let status = port.isEnabled ? "Enabled" : "Disabled"
            let portStr = port.portNumber.padding(toLength: 4, withPad: " ", startingAt: 0)
            print("\(portStr)  \(status)")
        }
        print("\nTotal: \(ports.count) ports")
    }
}

struct PortEnableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enable",
        abstract: "Enable a port by port number or MAC address, or enable all ports"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "Port number, MAC address, or 'all'")
    var portOrMAC: String?
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        guard let identifier = portOrMAC else {
            throw ArubaError.missingArgument("Port number, MAC address, or 'all' required. Use 'aruba1830 port enable <PORT/MAC/all>'")
        }
        
        let aliasResolver = globalOptions.loadMacAliasResolver()
        let resolvedMAC = aliasResolver.resolve(identifier)
        let macCandidate = resolvedMAC ?? identifier
        let macDescription: String
        if let normalized = resolvedMAC, normalized.caseInsensitiveCompare(identifier) != .orderedSame {
            macDescription = "\(normalized) (alias: \(identifier))"
        } else {
            macDescription = macCandidate
        }
        
        let logPath = globalOptions.resolvePortMacFilePath(host: config.host)
        let portLog = PortActivityLog(fileURL: logPath)
        do {
            try await portLog.load()
        } catch {
            emitWarning("Failed to load port MAC log at \(logPath.path): \(error)")
        }
        
        if identifier.lowercased() == "all" {
            let ports = try await client.getPorts(session: session)
            var enabledCount = 0
            for port in ports {
                let portNumber = port.portNumber
                if !port.isEnabled {
                    try await client.setPortState(session: session, port: portNumber, enabled: true)
                    enabledCount += 1
                }
                do {
                    try await portLog.remove(port: portNumber)
                } catch {
                    emitWarning("Failed to update port MAC log for port \(portNumber): \(error)")
                }
            }
            print("Enabled \(enabledCount) port(s)")
            return
        }
        
        if macCandidate.range(of: macAddressPattern, options: .regularExpression) != nil {
            let macEntries = try await client.findMACAddress(session: session, macAddress: macCandidate)
            if let match = macEntries.first {
                let portNumber = match.portNumber
                try await client.setPortState(session: session, port: portNumber, enabled: true)
                do {
                    try await portLog.remove(port: portNumber)
                } catch {
                    emitWarning("Failed to update port MAC log for port \(portNumber): \(error)")
                }
                print("Port \(portNumber) (MAC: \(macDescription)) enabled successfully")
                return
            }
            
            if let fallbackPort = try await portLog.port(forMAC: macCandidate) {
                try await client.setPortState(session: session, port: fallbackPort, enabled: true)
                do {
                    try await portLog.remove(port: fallbackPort)
                } catch {
                    emitWarning("Failed to update port MAC log for port \(fallbackPort): \(error)")
                }
                print("Port \(fallbackPort) (MAC: \(macDescription)) enabled using cached mapping")
                return
            }
            
            throw ArubaError.invalidMACAddress("MAC address \(macDescription) not found in MAC table or port log")
        }

        try await client.setPortState(session: session, port: identifier, enabled: true)
        do {
            try await portLog.remove(port: identifier)
        } catch {
            emitWarning("Failed to update port MAC log for port \(identifier): \(error)")
        }
        print("Port \(identifier) enabled successfully")
    }
}

enum MacBanAction: Equatable {
    case alreadyBanned(port: String)
    case banOn(port: String, previousPort: String?)
}

struct MacBanPlanner {
    static func action(savedPort: String?, macEntries: [MACTableEntry]) -> MacBanAction? {
        if let entry = macEntries.first {
            let currentPort = entry.portNumber
            if let saved = savedPort, saved != currentPort {
                return .banOn(port: currentPort, previousPort: saved)
            }
            return .banOn(port: currentPort, previousPort: nil)
        }
        
        if let saved = savedPort {
            return .alreadyBanned(port: saved)
        }
        
        return nil
    }
}

struct MacBanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ban",
        abstract: "Ban a MAC address by disabling its port and tracking moves"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "MAC address to ban")
    var macAddress: String
    
    @Flag(name: .long, help: "Force disable even if multiple MACs on port")
    var force: Bool = false
    
    mutating func run() async throws {
        let aliasResolver = globalOptions.loadMacAliasResolver()
        let resolvedMACValue = aliasResolver.resolve(macAddress)
        let normalizedInput = resolvedMACValue ?? macAddress
        let macDescription: String
        if let resolved = resolvedMACValue, resolved.caseInsensitiveCompare(macAddress) != .orderedSame {
            macDescription = "\(resolved) (alias: \(macAddress))"
        } else {
            macDescription = normalizedInput
        }
        
        guard normalizedInput.range(of: macAddressPattern, options: .regularExpression) != nil else {
            throw ArubaError.invalidMACAddress(macAddress)
        }
        
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        let logPath = globalOptions.resolvePortMacFilePath(host: config.host)
        let portLog = PortActivityLog(fileURL: logPath)
        do {
            try await portLog.load()
        } catch {
            emitWarning("Failed to load port MAC log at \(logPath.path): \(error)")
        }
        
        let savedPort: String?
        do {
            savedPort = try await portLog.port(forMAC: normalizedInput)
        } catch {
            emitWarning("Failed to read cached port for MAC \(macDescription): \(error)")
            savedPort = nil
        }
        
        let macEntries = try await client.findMACAddress(session: session, macAddress: normalizedInput)
        
        guard let action = MacBanPlanner.action(savedPort: savedPort, macEntries: macEntries) else {
            throw ArubaError.parsingError("MAC address \(macDescription) not found in MAC table")
        }
        
        switch action {
        case .alreadyBanned(let port):
            print("MAC \(macDescription) is already banned on port \(port) (cached)")
        case .banOn(let targetPort, let previousPort):
            if let previousPort = previousPort {
                try await client.setPortState(session: session, port: previousPort, enabled: true)
                do {
                    try await portLog.remove(mac: normalizedInput, from: previousPort)
                } catch {
                    emitWarning("Failed to update port MAC log for port \(previousPort): \(error)")
                }
                print("Port \(previousPort) re-enabled because MAC moved to port \(targetPort)")
            }
            
            do {
                let result = try await client.disablePortByMAC(session: session, macAddress: normalizedInput, force: force)
                if result.port != targetPort {
                    emitWarning("MAC \(macDescription) found on unexpected port \(result.port); expected \(targetPort)")
                }
                do {
                    try await portLog.record(port: result.port, macs: result.macs.map(\.macAddress))
                } catch {
                    emitWarning("Failed to update port MAC log for port \(result.port): \(error)")
                }
                print("Port \(result.port) (MAC: \(macDescription)) banned successfully")
            } catch ArubaError.multipleMACsOnPort(let port, let count) {
                print("⚠️  Warning: \(count) MAC addresses found on port \(port)")
                print("Use --force to disable anyway")
                throw ExitCode.failure
            }
        }
    }
}

struct PortDisableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Disable a port by port number or MAC address, or disable all ports"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "Port number, MAC address, or 'all'")
    var portOrMAC: String?
    
    @Flag(name: .long, help: "Force disable even if multiple MACs on port")
    var force: Bool = false
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        guard let identifier = portOrMAC else {
            throw ArubaError.missingArgument("Port number, MAC address, or 'all' required. Use 'aruba1830 port disable <PORT/MAC/all>'")
        }
        
        let aliasResolver = globalOptions.loadMacAliasResolver()
        let resolvedMAC = aliasResolver.resolve(identifier)
        let macCandidate = resolvedMAC ?? identifier
        let macDescription: String
        if let normalized = resolvedMAC, normalized.caseInsensitiveCompare(identifier) != .orderedSame {
            macDescription = "\(normalized) (alias: \(identifier))"
        } else {
            macDescription = macCandidate
        }
        
        let logPath = globalOptions.resolvePortMacFilePath(host: config.host)
        let portLog = PortActivityLog(fileURL: logPath)
        do {
            try await portLog.load()
        } catch {
            emitWarning("Failed to load port MAC log at \(logPath.path): \(error)")
        }
        
        if identifier.lowercased() == "all" {
            let ports = try await client.getPorts(session: session)
            let macTable = try await client.getMACTable(session: session)
            let macsByPort = Dictionary(grouping: macTable, by: { $0.portNumber }).mapValues { $0.map(\.macAddress) }
            var disabledCount = 0
            for port in ports {
                guard port.isEnabled else { continue }
                let portNumber = port.portNumber
                let macs = macsByPort[portNumber] ?? []
                try await client.setPortState(session: session, port: portNumber, enabled: false)
                do {
                    try await portLog.record(port: portNumber, macs: macs)
                } catch {
                    emitWarning("Failed to update port MAC log for port \(portNumber): \(error)")
                }
                disabledCount += 1
            }
            print("Disabled \(disabledCount) port(s)")
            return
        }
        
        if macCandidate.range(of: macAddressPattern, options: .regularExpression) != nil {
            do {
                let result = try await client.disablePortByMAC(session: session, macAddress: macCandidate, force: force)
                do {
                    try await portLog.record(port: result.port, macs: result.macs.map(\.macAddress))
                } catch {
                    emitWarning("Failed to update port MAC log for port \(result.port): \(error)")
                }
                print("Port \(result.port) (MAC: \(macDescription)) disabled successfully")
            } catch ArubaError.multipleMACsOnPort(let port, let count) {
                print("⚠️  Warning: \(count) MAC addresses found on port \(port)")
                print("Use --force to disable anyway")
                throw ExitCode.failure
            }
            return
        }
        
        let macEntries = try await client.getMACTableFiltered(session: session, port: identifier)
        try await client.setPortState(session: session, port: identifier, enabled: false)
        do {
            try await portLog.record(port: identifier, macs: macEntries.map(\.macAddress))
        } catch {
            emitWarning("Failed to update port MAC log for port \(identifier): \(error)")
        }
        print("Port \(identifier) disabled successfully")
    }
}

// MARK: - System Command

struct SystemCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "system",
        abstract: "System information and operations",
        subcommands: [
            SystemInfoCommand.self,
            SystemLogsCommand.self,
        ]
    )
}

struct SystemInfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Display system information"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        if let info = try await client.getSystemInfo(session: session) {
            print("System Information")
            print("==================")
            print("Device Name:      \(info.deviceName)")
            print("Model:            \(info.model)")
            print("Serial Number:    \(info.serialNumber)")
            print("Firmware Version: \(info.firmwareVersion)")
            print("MAC Address:      \(info.macAddress)")
        } else {
            print("No system information available")
        }
    }
}

struct SystemLogsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Display system logs"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .long, help: "Number of recent log entries to show")
    var tail: Int?
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        var logs = try await client.getLogs(session: session)
        
        if let tail = tail {
            logs = Array(logs.suffix(tail))
        }
        
        print("Timestamp             Severity  Message")
        print("--------------------  --------  -------")
        for log in logs {
            print("\(log.timestamp)  \(log.severity.padding(toLength: 8, withPad: " ", startingAt: 0))  \(log.message)")
        }
        print("\nTotal: \(logs.count) entries")
    }
}

// MARK: - VLAN Command

struct VLANCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vlan",
        abstract: "VLAN operations",
        subcommands: [VLANListCommand.self]
    )
}

struct VLANListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all VLANs"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        let vlans = try await client.getVLANs(session: session)
        
        print("VLAN ID  Name                Status")
        print("-------  ------------------  ------")
        for vlan in vlans {
            let status = vlan.status ?? "N/A"
            let vlanIDStr = String(format: "%-7d", vlan.vlanID)
            let nameStr = vlan.vlanName.padding(toLength: 18, withPad: " ", startingAt: 0)
            print("\(vlanIDStr)  \(nameStr)  \(status)")
        }
        print("\nTotal: \(vlans.count) VLANs")
    }
}

// MARK: - PoE Command

struct PoECommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "poe",
        abstract: "PoE management operations",
        subcommands: [
            PoEStatusCommand.self,
            PoEDisableCommand.self,
        ]
    )
}

struct PoEStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Display PoE status"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        let ports = try await client.getPoEPorts(session: session)
        
        print("Port  PoE Status  Power Status  Usage (W)")
        print("----  ----------  ------------  ---------")
        for port in ports {
            let status = port.poeEnabled ? "Enabled" : "Disabled"
            let powerStatus = port.powerStatus ?? "N/A"
            let usage = port.powerUsage.map { String(format: "%.2f", $0) } ?? "N/A"
            let portStr = port.interfaceName.padding(toLength: 4, withPad: " ", startingAt: 0)
            let statusStr = status.padding(toLength: 10, withPad: " ", startingAt: 0)
            let powerStr = powerStatus.padding(toLength: 12, withPad: " ", startingAt: 0)
            print("\(portStr)  \(statusStr)  \(powerStr)  \(usage)")
        }
        print("\nTotal: \(ports.count) PoE ports")
    }
}

struct PoEDisableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Disable PoE on a port"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "Port number")
    var port: String
    
    mutating func run() async throws {
        let config = try globalOptions.getConfiguration()
        let client = ArubaClient()
        let session = try await client.login(
            host: config.host,
            username: config.username,
            password: config.password,
            sessionToken: config.sessionToken,
            sessionCookie: config.sessionCookie
        )
        
        try await client.setPoEState(session: session, port: port, enabled: false)
        print("PoE disabled on port \(port) successfully")
    }
}
