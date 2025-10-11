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
}

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
            PortDisableCommand.self,
            PortDisableByMACCommand.self,
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
        abstract: "Enable a port"
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
        
        try await client.setPortState(session: session, port: port, enabled: true)
        print("Port \(port) enabled successfully")
    }
}

struct PortDisableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Disable a port"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "Port number or MAC address")
    var portOrMAC: String
    
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
        
        // Check if it's a MAC address or port number
        let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        if portOrMAC.range(of: macPattern, options: .regularExpression) != nil {
            // It's a MAC address
            do {
                try await client.disablePortByMAC(session: session, macAddress: portOrMAC, force: force)
                print("Port associated with MAC \(portOrMAC) disabled successfully")
            } catch ArubaError.multipleMACsOnPort(let port, let count) {
                print("⚠️  Warning: \(count) MAC addresses found on port \(port)")
                print("Use --force to disable anyway")
                throw ExitCode.failure
            }
        } else {
            // It's a port number
            try await client.setPortState(session: session, port: portOrMAC, enabled: false)
            print("Port \(portOrMAC) disabled successfully")
        }
    }
}

struct PortDisableByMACCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable-by-mac",
        abstract: "Disable port by MAC address"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "MAC address (format: 11:22:33:44:55:66)")
    var macAddress: String
    
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
        
        do {
            try await client.disablePortByMAC(session: session, macAddress: macAddress, force: force)
            print("Port associated with MAC \(macAddress) disabled successfully")
        } catch ArubaError.multipleMACsOnPort(let port, let count) {
            print("⚠️  Warning: \(count) MAC addresses found on port \(port)")
            print("Use --force to disable anyway")
            throw ExitCode.failure
        }
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
