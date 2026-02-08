import Foundation

func isValidIPv4(_ ip: String) -> Bool {
    let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return false }
    return parts.allSatisfy { part in
        guard let num = UInt8(part) else { return false }
        return String(num) == part
    }
}

func isValidCIDR(_ cidr: String) -> Bool {
    let components = cidr.split(separator: "/", omittingEmptySubsequences: false)
    guard components.count == 2 else { return false }
    guard isValidIPv4(String(components[0])) else { return false }
    guard let prefix = Int(components[1]), prefix >= 0, prefix <= 32 else { return false }
    return true
}

let args = Array(CommandLine.arguments.dropFirst())

guard args.count == 3 else {
    fputs("Usage: pinroutes-helper <add|delete> <network/cidr> <gateway>\n", stderr)
    exit(1)
}

let action = args[0]
let network = args[1]
let gateway = args[2]

guard action == "add" || action == "delete" else {
    fputs("Error: action must be 'add' or 'delete'\n", stderr)
    exit(1)
}

guard isValidCIDR(network) else {
    fputs("Error: invalid CIDR network '\(network)'\n", stderr)
    exit(1)
}

guard isValidIPv4(gateway) else {
    fputs("Error: invalid gateway '\(gateway)'\n", stderr)
    exit(1)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/sbin/route")
process.arguments = ["-n", action, network, gateway]

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
