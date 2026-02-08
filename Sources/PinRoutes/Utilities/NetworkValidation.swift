import Foundation

enum NetworkValidation {
    static func isValidIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = UInt8(part) else { return false }
            return String(num) == part // reject leading zeros
        }
    }

    static func isValidCIDR(_ cidr: String) -> Bool {
        let components = cidr.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2 else { return false }
        guard isValidIPv4(String(components[0])) else { return false }
        guard let prefix = Int(components[1]), prefix >= 0, prefix <= 32 else { return false }
        return true
    }

    static func isValidGateway(_ gateway: String) -> Bool {
        isValidIPv4(gateway)
    }

    static func networkAddress(from cidr: String) -> String? {
        let components = cidr.split(separator: "/")
        guard components.count == 2 else { return nil }
        return String(components[0])
    }

    static func subnetMask(from cidr: String) -> String? {
        let components = cidr.split(separator: "/")
        guard components.count == 2, let prefix = Int(components[1]), prefix >= 0, prefix <= 32 else {
            return nil
        }
        let mask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << (32 - prefix)
        let b1 = (mask >> 24) & 0xFF
        let b2 = (mask >> 16) & 0xFF
        let b3 = (mask >> 8) & 0xFF
        let b4 = mask & 0xFF
        return "\(b1).\(b2).\(b3).\(b4)"
    }
}
