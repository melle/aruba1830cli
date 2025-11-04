import Foundation

struct MacAliasResolver {
    static let empty = MacAliasResolver(aliasToMac: [:])
    
    private let aliasToMac: [String: String]
    
    init(aliasToMac: [String: String]) {
        self.aliasToMac = aliasToMac
    }
    
    func resolve(_ value: String) -> String? {
        aliasToMac[value.lowercased()]
    }
    
    static func load(from url: URL) throws -> MacAliasResolver {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var mapping: [String: String] = [:]
        
        contents.enumerateLines { rawLine, _ in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line.first != "#" else {
                return
            }
            
            guard let (mac, alias) = MacAliasResolver.parse(line: line) else {
                return
            }
            
            mapping[alias.lowercased()] = mac
        }
        
        return MacAliasResolver(aliasToMac: mapping)
    }
    
    private static func parse(line: String) -> (String, String)? {
        guard let separator = line.rangeOfCharacter(from: .whitespacesAndNewlines) else {
            return nil
        }
        
        let macPart = String(line[..<separator.lowerBound])
        let aliasPart = line[separator.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aliasPart.isEmpty else {
            return nil
        }
        
        let normalizedMac = PortActivityLog.normalize(mac: macPart)
        guard isValid(mac: normalizedMac) else {
            return nil
        }
        
        return (normalizedMac, aliasPart)
    }
    
    private static func isValid(mac: String) -> Bool {
        guard mac.count == 17 else {
            return false
        }
        return mac.range(of: #"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$"#, options: .regularExpression) != nil
    }
}
