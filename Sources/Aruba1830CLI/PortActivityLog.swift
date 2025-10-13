import Foundation

enum PortActivityLogError: Error {
    case readFailed(URL, any Error)
    case writeFailed(URL, any Error)
}

actor PortActivityLog {
    private let fileURL: URL
    private let fileManager: FileManager
    private var entries: [String: Set<String>] = [:]
    private var isLoaded = false
    
    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }
    
    func load() throws {
        guard !isLoaded else { return }
        defer { isLoaded = true }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            entries = [:]
            return
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw PortActivityLogError.readFailed(fileURL, error)
        }
        
        guard !data.isEmpty else {
            entries = [:]
            return
        }
        
        let decoded: [String: [String]]
        do {
            decoded = try JSONDecoder().decode([String: [String]].self, from: data)
        } catch {
            throw PortActivityLogError.readFailed(fileURL, error)
        }
        
        entries = decoded.reduce(into: [:]) { result, element in
            result[element.key] = Set(element.value.map { Self.normalize(mac: $0) })
        }
    }
    
    func record(port: String, macs: [String]) throws {
        try ensureLoaded()
        let normalized = macs.map { Self.normalize(mac: $0) }
        entries[port] = Set(normalized)
        try persist()
    }
    
    func remove(port: String) throws {
        try ensureLoaded()
        entries.removeValue(forKey: port)
        try persist()
    }
    
    func port(forMAC mac: String) throws -> String? {
        try ensureLoaded()
        let normalized = Self.normalize(mac: mac)
        return entries.first { _, value in
            value.contains(normalized)
        }?.key
    }
    
    func snapshot() throws -> [String: [String]] {
        try ensureLoaded()
        return entries.reduce(into: [:]) { result, element in
            result[element.key] = element.value.sorted()
        }
    }
    
    private func ensureLoaded() throws {
        if !isLoaded {
            try load()
        }
    }
    
    private func persist() throws {
        if entries.isEmpty {
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                } catch {
                    throw PortActivityLogError.writeFailed(fileURL, error)
                }
            }
            return
        }
        
        let encodable = entries.reduce(into: [String: [String]]()) { result, element in
            result[element.key] = element.value.sorted()
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        
        let data: Data
        do {
            data = try encoder.encode(encodable)
        } catch {
            throw PortActivityLogError.writeFailed(fileURL, error)
        }
        
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                throw PortActivityLogError.writeFailed(directoryURL, error)
            }
        }
        
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PortActivityLogError.writeFailed(fileURL, error)
        }
    }
    
    static func normalize(mac: String) -> String {
        let lowercase = mac.lowercased()
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        var hex = ""
        
        for scalar in lowercase.unicodeScalars {
            if allowed.contains(scalar) {
                hex.append(String(scalar))
            }
        }
        
        guard hex.count == 12 else {
            return lowercase
        }
        
        var result = ""
        for (index, character) in hex.enumerated() {
            if index > 0 && index % 2 == 0 {
                result.append(":")
            }
            result.append(character)
        }
        return result
    }
}
